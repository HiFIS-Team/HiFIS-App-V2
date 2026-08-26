#!/usr/bin/env python3
"""이미 깔린 센터 PC 를 갱신한다 — **토큰을 새로 발급하지 않는다.**

    python3 tools/scan/갱신.py

`scan.ps1` 만 새것으로 갈고 작업 스케줄러를 다시 등록한다. `config.json`
(서버 주소·단말 토큰)은 **손대지 않아서** 지금 쓰는 단말이 그대로 산다.

발급.py 와 갈라 둔 이유 — 저쪽은 부를 때마다 **새 토큰이 생긴다.**
스크립트만 갈고 싶은데 저걸 부르면 단말 행이 하나씩 늘고, 옛 토큰이 살아 있어
어느 것이 진짜인지 알 수 없게 된다.

서버에 붙지 않으므로 로그인도 필요 없다.
"""

import os

from installer import build, script_b64

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "갱신.ps1.txt")

with open(out, "w", encoding="utf-8") as f:
    f.write(build(script_b64(os.path.join(here, "scan.ps1"))))

print(f"만들었습니다 — {out}")
print("\n센터 PC 의 **관리자 PowerShell** 에 이 파일 내용을 통째로 붙여넣으면 끝입니다.")
print("지점마다 다르지 않으므로 **세 곳에 같은 것**을 쓰면 됩니다.")
