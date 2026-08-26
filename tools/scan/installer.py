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
$act = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $d\scan.ps1"
$prn = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# 켤 때 + 10분마다 (죽어 있으면 다시 뜬다)
$trgBoot = New-ScheduledTaskTrigger -AtStartup
try {
    $trgRep = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration ([TimeSpan]::MaxValue)
} catch {
    # 옛 윈도우는 MaxValue 를 못 받는다 — 사실상 무한인 값으로 떨어진다
    $trgRep = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 3650)
}

$set = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $taskName -Action $act -Trigger @($trgBoot, $trgRep) `
    -Principal $prn -Settings $set -Force | Out-Null
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
        'Write-Host "설치됨. 로그를 보려면:"',
        'Write-Host "  Get-Content C:\\HiFIS\\scan.log -Wait -Tail 20"',
        "",
    ]
    return "\n".join(lines)
