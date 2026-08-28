#!/usr/bin/env bash
# 서버 OpenAPI 스냅샷을 다시 받는다 (test/fixtures/openapi.json)
#
# 이 스냅샷을 `test/api_contract_test.dart` 가 읽어서, 앱이 `fromJson` 에서
# 읽는 필드가 서버 응답에 실제로 오는 값인지 대조한다.
#
# **운영(api.hifis.app)은 /openapi.json 을 닫아 두었다 (404).** 그게 맞는
# 설정이라 로컬 개발 서버에서 받는다. 서버 레포에서 먼저 띄운다:
#
#     cd ~/Documents/HiFIS-Server-V2 && docker compose up -d
#
# 서버 스키마를 고쳤으면 이걸 돌리고 테스트를 다시 돌린다. 테스트가 깨지면
# **앱이 그 변경을 아직 안 따라간 것**이다 — 스냅샷만 갈고 넘어가면 안 된다.
set -euo pipefail

URL="${1:-http://localhost:8001/openapi.json}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/test/fixtures/openapi.json"

curl -fsS --max-time 30 "$URL" -o /tmp/hifis-openapi-raw.json || {
  echo "받지 못했다: $URL" >&2
  echo "로컬 서버가 떠 있는지 본다 — cd ~/Documents/HiFIS-Server-V2 && docker compose up -d" >&2
  exit 1
}

# 필요한 것만 남긴다 — 285KB → 56KB. 경로·설명·예시는 대조에 안 쓴다
python3 - "$OUT" <<'PY'
import json, sys

raw = json.load(open("/tmp/hifis-openapi-raw.json"))
out = {
    "_": "서버 OpenAPI 스냅샷 — 손으로 고치지 않는다. tool/refresh_openapi.sh 로 다시 받는다.",
    "version": raw.get("info", {}).get("version"),
    "schemas": {
        name: {
            "required": sch.get("required", []),
            "properties": {
                f: (
                    {"nullable": True}
                    if ("anyOf" in p and any(x.get("type") == "null" for x in p["anyOf"]))
                    else {}
                )
                for f, p in sch.get("properties", {}).items()
            },
        }
        for name, sch in raw["components"]["schemas"].items()
    },
}
with open(sys.argv[1], "w") as f:
    json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    f.write("\n")
print(f"스키마 {len(out['schemas'])}개 · 서버 판 {out['version']}")
PY

rm -f /tmp/hifis-openapi-raw.json
echo "→ $OUT"
echo "이제 확인한다:  flutter test test/api_contract_test.dart"
