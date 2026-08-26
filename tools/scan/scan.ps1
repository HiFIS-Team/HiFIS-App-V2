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
$BeatSec    = 300    # 생존 신호 간격(5분) — 서버의 판정 기준(20분)보다 넉넉히 짧게

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

# ---------------------------------------------------------------------------
# 생존 신호 (2026-08-26)
#
# 화순에서 "바코드가 안 된다"는 말이 왔는데 **서버 쪽에 아무 흔적이 없었다.**
# 이 프로그램이 안 돌면 스캐너가 읽은 값이 PC 밖으로 못 나가기 때문이다.
# 제일 나쁜 건 **스캐너 부저가 그때도 삑 소리를 낸다**는 것 — 찍은 사람은
# 됐다고 믿고 가고, 저녁에 결근 알림이 나가서 안 나온 사람처럼 보인다.
#
# 그래서 "나 살아 있다"를 따로 말한다. 스캔이 없는 것과 프로그램이 죽은 것을
# 서버가 가를 수 있어야 대표에게 맞는 말을 보낸다.
#
# **실패해도 그냥 넘어간다.** 이건 곁다리라, 여기서 막히면 정작 출퇴근이 안 찍힌다.
# ---------------------------------------------------------------------------

function Send-Signal($path, $body) {
    try {
        # 이름이 $args 면 안 된다 — PowerShell 자동 변수(함수 인자)와 겹친다
        $req = @{
            Uri        = "$apiBase/scan-terminals/$path"
            Method     = 'Post'
            Headers    = @{ 'X-Terminal-Token' = $token }
            TimeoutSec = 10
        }
        if ($body) {
            $req['ContentType'] = 'application/json'
            $req['Body'] = $body
        }
        Invoke-RestMethod @req | Out-Null
        return $true
    } catch {
        return $false
    }
}

# 지금 잡고 있는 포트를 같이 보낸다 — null 이면 서버가 '스캐너를 못 찾는 중'으로 읽는다
function Send-Beat($portName) {
    $body = @{ scannerPort = $portName } | ConvertTo-Json -Compress
    Send-Signal 'heartbeat' $body | Out-Null
    $script:lastBeat = Get-Date
}

$script:lastBeat = Get-Date
if (Send-Signal 'startup' $null) {
    Write-Log "시작 신호 전송"
} else {
    # 서버에 못 닿아도 계속 돈다 — 스캔은 나중에 붙을 수 있다
    Write-Log "시작 신호 실패 (서버에 못 닿음) — 계속 진행합니다"
}

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
        # 스캐너를 못 찾는 동안에도 신호는 보낸다 — **여기가 제일 중요하다.**
        # 프로그램은 도는데 스캐너만 죽은 경우라, 신호가 끊기면 서버가
        # 'PC 가 꺼졌다'고 잘못 말한다. 포트는 null 로 보낸다.
        if (((Get-Date) - $script:lastBeat).TotalSeconds -ge $BeatSec) { Send-Beat $null }
        Start-Sleep -Seconds $RetrySec
        continue
    }

    $port = New-Object System.IO.Ports.SerialPort $portName, $BaudRate, 'None', 8, 'One'
    try {
        $port.Open()
        Write-Log "$portName 연결됨"
        Send-Beat $portName   # 붙자마자 알린다 — 다음 주기(5분)를 기다리지 않는다
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
            if (((Get-Date) - $script:lastBeat).TotalSeconds -ge $BeatSec) { Send-Beat $portName }
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
