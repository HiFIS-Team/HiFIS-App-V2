#!/usr/bin/env python3
"""지점 단말 토큰 발급 — 운영 서버에 대고 한 번만 돌린다.

지점을 고르면 토큰을 만들고 `config-<지점>.json` 까지 써 준다.
그 파일을 센터 PC 의 `C:\\HiFIS\\config.json` 으로 복사하면 된다.

    python3 tools/scan/발급.py

**토큰은 이때 한 번만 볼 수 있다** — 서버는 해시만 들고 있다.
놓치면 폐기하고 새로 발급한다 (설치.md 참고).
"""

import base64
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

from installer import build, script_b64

API = "https://api.hifis.app"


def call(path, method="GET", token=None, body=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers=headers,
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or b"{}")
        except Exception:
            return e.code, {}


email = input("대표 계정 이메일: ").strip()
password = getpass.getpass("비밀번호: ")

status, data = call("/auth/login", "POST", body={"email": email, "password": password})
if status != 200:
    sys.exit(f"로그인 실패 ({status}) {data}")
token = data["accessToken"]
me_status, me = call("/auth/me", token=token)
if me.get("role") != "MASTER":
    sys.exit(f"MASTER 계정이어야 합니다 (지금 {me.get('role')})")
print(f"로그인 ✅  {me.get('name')} ({me.get('role')})\n")

status, branches = call("/branches", token=token)
# HQ(전체)는 실제 센터가 아니라 단말을 둘 자리가 아니다.
# 응답은 isHq 가 아니라 type 으로 온다 ("HQ" | "BRANCH")
sites = [b for b in branches if b.get("type") != "HQ"]
for i, b in enumerate(sites, 1):
    print(f"  {i}. {b['name']}")
choice = int(input("\n단말을 둘 지점 번호: ").strip())
branch = sites[choice - 1]
name = input(f"단말 이름 [{branch['name']}점 카운터]: ").strip() or f"{branch['name']}점 카운터"

status, created = call(
    "/scan-terminals", "POST", token=token, body={"branchId": branch["id"], "name": name}
)
if status != 201:
    sys.exit(f"발급 실패 ({status}) {created}")

out = f"config-{branch['name']}.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"apiBase": API, "terminalToken": created["token"]}, f, ensure_ascii=False, indent=2)

# 붙여넣기 덩어리는 `installer.py` 가 만든다 — 갱신.py 와 같은 조각을 쓴다.
# (작업 스케줄러 강화·USB 절전 끄기가 그 안에 들어 있다)
here = os.path.dirname(os.path.abspath(__file__))
config_b64 = base64.b64encode(
    json.dumps({"apiBase": API, "terminalToken": created["token"]}, ensure_ascii=False).encode()
).decode()
installer = build(script_b64(os.path.join(here, "scan.ps1")), config_b64)

installer_path = f"설치-{branch['name']}.ps1.txt"
with open(installer_path, "w", encoding="utf-8") as f:
    f.write(installer)

print(f"\n발급 완료 — {created['name']}")
print(f"  토큰 : {created['token']}")
print(f"  설정 : {out}")
print(f"  설치 : {installer_path}   ← 이 파일 내용을 센터 PC 의 **관리자 PowerShell** 에 통째로 붙여넣으면 끝")
print("\n토큰은 다시 볼 수 없습니다 — 잃어버리면 폐기하고 새로 발급합니다.")
