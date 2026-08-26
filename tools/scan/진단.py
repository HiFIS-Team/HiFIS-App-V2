#!/usr/bin/env python3
"""현장 진단 덩어리를 만든다 — `진단.ps1.txt`.

    python3 tools/scan/진단.py

**왜 base64 로 싸는가.** 진단 명령을 메시지에 그대로 적어 보내면, 받는 쪽에서
서식 있는 곳(카톡·메모·리치텍스트)을 거치면서 RTF 로 변해 붙여넣기가 깨진다.
2026-08-26 현장에서 실제로 겪었다 — 줄 끝마다 `\\`, 한글이 `\\uc0\\u52636`,
`$_` 의 밑줄이 먹혀 `$.` 이 됐다.

base64 는 **영문·숫자·`+/=` 뿐**이라 한글도 밑줄도 없다. 한글은 전부 그 안에
들어가 있어서 무엇을 거쳐도 안 깨진다. 설치·갱신 덩어리와 같은 방식이다.

아무것도 바꾸지 않고 **읽기만 한다.**
"""

import base64
import os

DIAG = r'''
Write-Host "===== HiFIS 스캐너 진단 =====" -ForegroundColor Cyan
Write-Host "지금 시각 : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "PC 켠 시각: $((Get-CimInstance Win32_OperatingSystem).LastBootUpTime)"

Write-Host ""
Write-Host "--- 1. 작업 스케줄러 ---"
$t = Get-ScheduledTask -TaskName "HiFIS *" -ErrorAction SilentlyContinue
if ($t) {
    $i = $t | Get-ScheduledTaskInfo
    Write-Host "이름          : $($t.TaskName)"
    Write-Host "상태          : $($t.State)"
    Write-Host "마지막 실행   : $($i.LastRunTime)"
    Write-Host "마지막 결과   : $($i.LastTaskResult)   (267009 = 실행중)"
    try {
        $x = [xml](Export-ScheduledTask -TaskName $t.TaskName)
        Write-Host "실행시간 제한 : $($x.Task.Settings.ExecutionTimeLimit)   (PT0S 여야 새 방식)"
        if ($x.Task.Triggers.TimeTrigger) {
            Write-Host "반복 트리거   : 있음 (새 방식)"
        } else {
            Write-Host "반복 트리거   : 없음  <-- 옛 방식"
        }
    } catch {
        Write-Host "설정을 못 읽었습니다"
    }
} else {
    Write-Host "작업이 등록돼 있지 않습니다  <-- 원인일 수 있음"
}

Write-Host ""
Write-Host "--- 2. 프로그램이 돌고 있나 ---"
$all = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue
$p = $all | Where-Object { $_.CommandLine -like '*scan.ps1*' }
if ($p) {
    foreach ($one in $p) {
        Write-Host "돌고 있음  PID $($one.ProcessId)  시작 $($one.CreationDate)"
    }
} else {
    Write-Host "안 돌고 있음  <-- 원인일 가능성이 큼"
}

Write-Host ""
Write-Host "--- 3. 스캐너 ---"
$ports = [System.IO.Ports.SerialPort]::GetPortNames()
if ($ports) {
    Write-Host "COM 포트  : $($ports -join ', ')"
} else {
    Write-Host "COM 포트  : 없음  <-- 스캐너가 PC 에 안 잡힘"
}
$dev = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
       Where-Object { $_.PNPDeviceID -match 'VID_04D8' }
if ($dev) {
    foreach ($d in $dev) { Write-Host "장치      : $($d.Name)  상태 $($d.Status)" }
} else {
    Write-Host "장치      : 스캐너를 못 찾음 (케이블/전원/CDC 모드 확인)"
}

Write-Host ""
Write-Host "--- 4. 로그 ---"
if (Test-Path C:\HiFIS\scan.log) {
    $f = Get-Item C:\HiFIS\scan.log
    Write-Host "마지막 기록 : $($f.LastWriteTime)"
    Write-Host "--- 마지막 20줄 ---"
    Get-Content C:\HiFIS\scan.log -Tail 20 -Encoding UTF8
} else {
    Write-Host "로그 파일이 없습니다  <-- 한 번도 안 돌았을 수 있음"
}
Write-Host ""
Write-Host "===== 끝 ====="
'''


def chunk(text, width=200):
    return "\n".join(f"'{text[i:i + width]}'" for i in range(0, len(text), width))


# BOM 을 붙인다 — Windows PowerShell 5.1 은 BOM 이 없으면 .ps1 을 CP949 로 읽어
# 한글이 깨지고, 깨진 바이트가 따옴표를 먹어 파일 전체가 파싱 에러가 난다.
b64 = base64.b64encode("\ufeff".encode("utf-8") + DIAG.encode("utf-8")).decode()

block = f"""$f = "$env:TEMP\\hifis-diag.ps1"
$s = @(
{chunk(b64)}
) -join ''
[IO.File]::WriteAllBytes($f, [Convert]::FromBase64String($s))
powershell -ExecutionPolicy Bypass -File $f
"""

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "진단.ps1.txt")
with open(out, "w", encoding="utf-8") as fp:
    fp.write(block)
print(f"만들었습니다 — {out}")
print("\n메모장으로 열어 Ctrl+A → Ctrl+C 한 뒤, 관리자 PowerShell 에 우클릭으로 붙여넣습니다.")
print("아무것도 바꾸지 않고 읽기만 합니다.")
