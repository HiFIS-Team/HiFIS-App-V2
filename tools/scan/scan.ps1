# HiFIS 지점 출퇴근 스캐너
#
# 지점 카운터 PC 에서 **화면 없이** 돌면서, 바코드 스캐너(USB CDC)가 보내는
# 사번을 서버로 넘긴다. HiFIS 앱을 켜 둘 필요가 없다 — 그 PC 는 회원 등록 등에
# 같이 쓰는 공용 컴퓨터라 사람 계정으로 켜 두면 누구나 급여·사내톡·조직도를
# 들여다볼 수 있다.
#
# 쓰는 자격은 **지점 단말 토큰**이라 할 수 있는 일이 출퇴근 찍기뿐이다.
# 이 파일이 통째로 새어도 남의 급여나 대화는 안 열린다.
#
# 설치는 [설치.md] 참고 — 파일 복사 + 작업 스케줄러 등록 한 줄이 전부다.

param(
    # 설정 파일 — 서버 주소·단말 토큰이 들어 있다
    [string]$ConfigPath = "$PSScriptRoot\config.json",
    [string]$LogPath    = "$PSScriptRoot\scan.log"
)

$ErrorActionPreference = 'Continue'

# 스캐너가 쓰는 값 — JYK-EP8280J 기준 (2026-08-07 실기기 확인)
$BaudRate   = 9600
$RetrySec   = 5      # 포트를 못 찾거나 끊겼을 때 다시 볼 간격
$RepeatSec  = 10     # 같은 사번이 이 안에 또 오면 버린다 (아래 설명)

function Write-Log($message) {
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
    Write-Host $line
    try {
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
        # 로그가 끝없이 커지지 않게 5MB 넘으면 한 번 접는다
        if ((Get-Item $LogPath).Length -gt 5MB) {
            Move-Item $LogPath "$LogPath.1" -Force
        }
    } catch { }
}

if (-not (Test-Path $ConfigPath)) {
    Write-Log "설정 파일이 없습니다: $ConfigPath"
    exit 1
}
$config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$apiBase = $config.apiBase.TrimEnd('/')
$token   = $config.terminalToken
if (-not $apiBase -or -not $token) {
    Write-Log "설정에 apiBase 또는 terminalToken 이 없습니다"
    exit 1
}
Write-Log "시작 — 서버 $apiBase"

# 사번 -> 마지막으로 보낸 시각
#
# 서버의 /attendance/scan 은 **토글**이라 같은 사번이 연달아 오면
# 출근 찍고 바로 퇴근이 된다. 스캐너 자체는 재읽기를 안 하지만, 직원이
# "안 찍혔나?" 하고 두 번 대는 것까지는 못 막는다.
$lastSent = @{}

function Send-Scan($code) {
    $now = Get-Date
    if ($lastSent.ContainsKey($code)) {
        if (($now - $lastSent[$code]).TotalSeconds -lt $RepeatSec) {
            Write-Log "$code — 중복이라 건너뜀"
            return
        }
    }
    $lastSent[$code] = $now
    try {
        $body = @{ code = $code } | ConvertTo-Json -Compress
        $res = Invoke-RestMethod -Uri "$apiBase/attendance/scan" -Method Post `
            -Headers @{ 'X-Terminal-Token' = $token } `
            -ContentType 'application/json' -Body $body -TimeoutSec 10
        $what = if ($res.checkOut) { '퇴근' } else { '출근' }
        Write-Log "$code $what"
    } catch {
        # 실패했으면 막아두지 않는다 — 바로 다시 댈 수 있어야 한다
        $lastSent.Remove($code)
        # 네트워크가 끊겼으면 Response 자체가 없다 — 거기서 또 터지면 안 된다
        $status = 'network'
        try { $status = $_.Exception.Response.StatusCode.value__ } catch { }
        Write-Log "$code 실패 ($status) $($_.Exception.Message)"
    }
}

# 스캐너로 보이는 포트를 고른다
#
# **아무 COM 이나 열면 안 된다** — 다른 장비의 포트를 열어 그 기기를 방해할 수
# 있다. 확인된 기기는 Microchip CDC(VID 04D8 · PID 000A, 'DECODER_CDC')다.
function Find-ScannerPort {
    $names = [System.IO.Ports.SerialPort]::GetPortNames()
    if ($names.Count -eq 0) { return $null }
    try {
        $devices = Get-CimInstance Win32_PnPEntity -ErrorAction Stop |
            Where-Object { $_.Name -match '\((COM\d+)\)' }
        foreach ($d in $devices) {
            if ($d.Name -match '\((COM\d+)\)') {
                $port = $Matches[1]
                if ($names -notcontains $port) { continue }
                if ($d.PNPDeviceID -match 'VID_04D8&PID_000A' -or
                    $d.Name -match 'DECODER|BARCODE|SCANNER') {
                    return $port
                }
            }
        }
    } catch { }
    # 못 가렸으면 COM 이 하나뿐일 때만 그걸 쓴다 (여럿이면 함부로 안 건드린다)
    if ($names.Count -eq 1) { return $names[0] }
    Write-Log "스캐너를 못 가렸습니다 — 붙어 있는 포트: $($names -join ', ')"
    return $null
}

while ($true) {
    $portName = Find-ScannerPort
    if (-not $portName) {
        Start-Sleep -Seconds $RetrySec
        continue
    }

    $port = New-Object System.IO.Ports.SerialPort $portName, $BaudRate, 'None', 8, 'One'
    try {
        $port.Open()
        Write-Log "$portName 연결됨"
    } catch {
        Write-Log "$portName 열기 실패 — $($_.Exception.Message)"
        Start-Sleep -Seconds $RetrySec
        continue
    }

    $buffer = ''
    while ($port.IsOpen) {
        try {
            if ($port.BytesToRead -gt 0) {
                $buffer += $port.ReadExisting()
                # 스캐너가 붙여 보내는 터미네이터는 LF(0x0A) — CR 도 같이 받아 준다
                while ($true) {
                    $index = $buffer.IndexOfAny([char[]]@("`r", "`n"))
                    if ($index -lt 0) { break }
                    $line = $buffer.Substring(0, $index).Trim()
                    $buffer = $buffer.Substring($index + 1)
                    if ($line) { Send-Scan $line }
                }
                # 터미네이터가 영영 안 오는 쓰레기가 쌓이지 않게 자른다
                if ($buffer.Length -gt 128) { $buffer = '' }
            }
            Start-Sleep -Milliseconds 50
        } catch {
            # 케이블이 빠지면 여기로 온다 — 다시 꽂으면 바깥 while 이 이어 붙인다
            Write-Log "$portName 끊김 — $($_.Exception.Message)"
            break
        }
    }

    try { $port.Close() } catch { }
    Start-Sleep -Seconds $RetrySec
}
