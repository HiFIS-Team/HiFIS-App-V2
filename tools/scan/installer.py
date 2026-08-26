"""붙여넣기 설치 덩어리를 만드는 조각들 — 발급.py · 갱신.py 가 같이 쓴다.

센터 PC 에 파일을 옮길 방법이 마땅치 않아서(Git 도 USB 도 없을 수 있다)
`scan.ps1` 을 통째로 base64 로 실어 **한 번 붙여넣으면 끝나는** 덩어리를 만든다.
"""

import base64

# ---------------------------------------------------------------------------
# 작업 스케줄러 등록 — `schtasks /create` 로는 부족하다
# ---------------------------------------------------------------------------
#
# 예전에는 이 한 줄이었다.
#
#     schtasks /create /tn "HiFIS 출퇴근" /sc onstart /ru SYSTEM /rl HIGHEST /f /tr "..."
#
# **켤 때 한 번 띄우는 게 전부라, 그 뒤에 죽으면 다음 부팅까지 안 돌아온다.**
# 게다가 `schtasks` 로 만든 작업은 **실행 시간 제한이 기본 3일**이라, PC 를
# 사흘 넘게 안 끄면 작업 스케줄러가 **스스로 죽인다.** "잘 되다가 어느 날
# 안 된다"의 유력한 원인이다 — 아무 로그도 안 남고 조용히 사라진다.
#
# 그래서 셋을 건다.
#
#   1. 실행 시간 제한 없음      사흘마다 죽는 것을 막는다
#   2. 10분마다 재시도 트리거    무슨 이유로 죽었든 10분 안에 돌아온다
#   3. 실패 시 자동 재시작       프로세스가 오류로 끝나면 1분 뒤 다시
#
# 2번이 실질적인 안전망이다. `MultipleInstances IgnoreNew` 라 **이미 돌고
# 있으면 새로 안 띄운다** — 10분마다 확인만 하고 지나간다.
TASK_BLOCK = r"""
$taskName = 'HiFIS 출퇴근'
$act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $d\scan.ps1"
$prn = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$set = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
$trgBoot = New-ScheduledTaskTrigger -AtStartup

# 반복 트리거의 기간 — **`[TimeSpan]::MaxValue` 를 쓰면 안 된다.**
# `P99999999DT23H59M59S` 로 펼쳐져서 작업 스케줄러가 거부한다
# (2026-08-26 화순에서 실제로 겪었다 — HRESULT 0x80041318).
# 게다가 그 오류는 트리거를 만들 때가 아니라 **등록할 때** 나서,
# 트리거 생성만 try 로 감싸면 안 걸린다. 등록까지 감싸야 한다.
$ok = $false
foreach ($days in 3650, 365, 30) {
    try {
        $rep = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days $days)
        Register-ScheduledTask -TaskName $taskName -Action $act -Trigger @($trgBoot, $rep) -Principal $prn -Settings $set -Force -ErrorAction Stop | Out-Null
        Write-Host "작업 등록됨 — 켤 때 + 10분마다 (반복 $days 일)"
        $ok = $true
        break
    } catch { }
}
if (-not $ok) {
    # 반복 트리거가 어떤 값으로도 안 되면, **최소한 실행시간 제한 해제는 살린다.**
    # 그것만으로도 사흘마다 죽는 것은 막힌다.
    Register-ScheduledTask -TaskName $taskName -Action $act -Trigger @($trgBoot) -Principal $prn -Settings $set -Force | Out-Null
    Write-Host "주의: 반복 트리거를 못 걸었습니다 — 켤 때만 뜹니다 (실행시간 제한 해제는 적용됨)"
}
"""


# ---------------------------------------------------------------------------
# USB 절전 끄기 — 스캐너가 잠들어 사라지는 것을 막는다
# ---------------------------------------------------------------------------
#
# 윈도우는 전기를 아끼려고 USB 장치를 재운다(선택적 절전). 재운 장치는 COM
# 목록에서 빠지는데, **우리가 쥔 포트 객체는 예외를 안 던져서** 조용히 먹통이
# 된다 — `scan.ps1` 의 워치독이 그걸 잡지만, 애초에 안 재우는 게 낫다.
#
# 둘을 끈다. 전역 설정은 콘센트 전원일 때만 손댄다(카운터 PC 는 늘 꽂혀 있다).
# 장치별 설정은 **스캐너(VID_04D8&PID_000A)에만** 건다 — 다른 USB 장치까지
# 건드리면 이 PC 의 다른 기기에 영향이 간다.
USB_BLOCK = r"""
# 전역 — USB 선택적 절전 끄기 (콘센트 전원)
try {
    powercfg /setacvalueindex SCHEME_CURRENT `
        2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
} catch { }

# 장치별 — 스캐너만
try {
    Get-CimInstance Win32_PnPEntity -ErrorAction Stop |
        Where-Object { $_.PNPDeviceID -match 'VID_04D8&PID_000A' } |
        ForEach-Object {
            $k = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters"
            if (Test-Path $k) {
                New-ItemProperty -Path $k -Name 'EnhancedPowerManagementEnabled' `
                    -Value 0 -PropertyType DWord -Force | Out-Null
                New-ItemProperty -Path $k -Name 'AllowIdleIrpInD3' `
                    -Value 0 -PropertyType DWord -Force | Out-Null
            }
        }
} catch { }
"""


def chunk(text, width=200):
    """base64 를 여러 줄로 쪼갠다.

    **한 줄로 만들면 안 된다** — 윈도우 콘솔은 한 번에 붙여넣는 줄이 8192자를
    넘으면 잘라 버린다.
    """
    return "\n".join(f"'{text[i:i + width]}'" for i in range(0, len(text), width))


def script_b64(path):
    """`scan.ps1` 을 **바이트 그대로** 싣는다.

    ⚠️ **앞의 UTF-8 BOM 을 떼면 안 된다.** Windows PowerShell 5.1 은 `.ps1` 에
    BOM 이 없으면 UTF-8 이 아니라 시스템 코드페이지(한국어 윈도우면 CP949)로
    읽는다. 그러면 주석·로그의 한글이 깨지고, 깨진 바이트가 따옴표를 먹어서
    **파일 전체가 파싱 에러**가 난다 (2026-08-07 화순점에서 실제로 겪었다 —
    `Try 문에 해당 Catch 블록이 없습니다`).
    """
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


#: 끝에서 **실제로 걸렸는지 확인해서 보여준다.**
#
# 2026-08-26 화순에서 작업 등록이 실패했는데도 `설치됨.` 이 떠서, 현장에서는
# 다 된 줄 알고 나왔다. **하고 나서 확인하지 않으면 실패가 성공처럼 보인다.**
VERIFY_BLOCK = r"""
Write-Host ""
Write-Host "===== 확인 ====="
$chk = Get-ScheduledTask -TaskName 'HiFIS 출퇴근' -ErrorAction SilentlyContinue
if ($chk) {
    $x = [xml](Export-ScheduledTask -TaskName 'HiFIS 출퇴근')
    $limit = $x.Task.Settings.ExecutionTimeLimit
    $hasRep = [bool]$x.Task.Triggers.TimeTrigger.Repetition
    Write-Host "작업 상태     : $($chk.State)"
    Write-Host "실행시간 제한 : $limit $(if ($limit -eq 'PT0S') {'(정상)'} else {'<-- 안 걸렸습니다'})"
    Write-Host "반복 트리거   : $(if ($hasRep) {'있음 (정상)'} else {'없음 <-- 안 걸렸습니다'})"
    if ($limit -eq 'PT0S' -and $hasRep) {
        Write-Host "-> 설정 정상" -ForegroundColor Green
    } else {
        Write-Host "-> 설정이 덜 걸렸습니다. 이 화면을 그대로 알려 주세요" -ForegroundColor Yellow
    }
} else {
    Write-Host "작업이 등록되지 않았습니다 <-- 이 화면을 그대로 알려 주세요" -ForegroundColor Red
}
$run = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*scan.ps1*' }
Write-Host "프로그램      : $(if ($run) {'돌고 있음 (정상)'} else {'안 돌고 있음 <-- 알려 주세요'})"
Write-Host ""
Write-Host "로그를 보려면:  Get-Content C:\HiFIS\scan.log -Wait -Tail 20"
"""


def build(script_base64, config_base64=None):
    """붙여넣기 덩어리 한 장.

    [config_base64] 를 안 주면 **설정 파일을 안 건드린다** — 이미 깔린 PC 를
    갱신할 때 쓴다. 토큰을 새로 발급하지 않으므로 그 단말은 그대로 산다.
    """
    lines = [
        "$d='C:\\HiFIS'; New-Item -ItemType Directory -Force -Path $d | Out-Null",
        "$s = @(",
        chunk(script_base64),
        ") -join ''",
    ]
    if config_base64 is not None:
        lines += ["$c = @(", chunk(config_base64), ") -join ''"]
    lines += ['[IO.File]::WriteAllBytes("$d\\scan.ps1", [Convert]::FromBase64String($s))']
    if config_base64 is not None:
        lines += ['[IO.File]::WriteAllBytes("$d\\config.json", [Convert]::FromBase64String($c))']
    else:
        # **`return`·`exit` 를 쓰지 않는다** — 콘솔에 붙여넣는 덩어리라
        # `exit` 는 창을 닫아 버리고 `return` 은 최상위에서 뜻이 애매하다.
        # 설정이 없으면 알리기만 하고, 실제로 못 도는 것은 scan.ps1 이 로그에 남긴다.
        lines += [
            'if (-not (Test-Path "$d\\config.json")) {',
            '    Write-Host "⚠ config.json 이 없습니다 — 이 PC 는 갱신이 아니라 새 설치(발급.py)가 필요합니다"',
            "}",
        ]
    lines += [
        TASK_BLOCK.strip(),
        USB_BLOCK.strip(),
        # 지금 도는 것을 끊고 새 스크립트로 다시 띄운다 — 안 그러면 옛 코드가 계속 돈다
        'Stop-ScheduledTask -TaskName "HiFIS 출퇴근" -ErrorAction SilentlyContinue',
        'Start-ScheduledTask -TaskName "HiFIS 출퇴근"',
        'Start-Sleep -Seconds 3',
        VERIFY_BLOCK.strip(),
        "",
    ]
    inner = "\n".join(lines)

    # **덩어리 전체를 다시 base64 로 싼다.**
    #
    # 그냥 적어 보내면 받는 쪽에서 서식 있는 곳(카톡·메모)을 거치며 RTF 로 변해
    # 붙여넣기가 깨진다 — 2026-08-26 현장에서 겪었다. 줄 끝마다 `\`, 한글이
    # `\uc0\u52636`, `$_` 의 밑줄이 먹혀 `$.` 이 됐다.
    #
    # base64 는 **영문·숫자·`+/=` 뿐**이라 한글도 밑줄도 없다. 바깥 껍데기에도
    # 그 둘이 안 들어가게 영어로만 쓴다.
    payload = base64.b64encode("\ufeff".encode("utf-8") + inner.encode("utf-8")).decode()
    return (
        '$f = "$env:TEMP\\hifis-setup.ps1"\n'
        "$b = @(\n" + chunk(payload) + "\n) -join ''\n"
        "[IO.File]::WriteAllBytes($f, [Convert]::FromBase64String($b))\n"
        "powershell -ExecutionPolicy Bypass -File $f\n"
    )
