import json
from pathlib import Path

raw = Path(
    r"C:\Users\Shamah\.cursor\projects\c-Users-Shamah-Documents-FlutterProjects-hdhomesproject\agent-tools\e713dff8-2004-434c-a499-5be54e0e499f.txt"
).read_text(encoding="utf-8")
data = json.loads(raw)
items = data["result"]["lints"]
for item in items:
    print("=" * 60)
    print(item.get("level"), item.get("name"))
    meta = item.get("metadata") or {}
    print("meta keys", list(meta)[:20])
    for key in ("name", "schema", "type", "entity"):
        if key in meta:
            print(key, meta[key])
    detail = item.get("detail") or ""
    print(detail[:500])
    print("title", item.get("title"))
    print("remediation", str(item.get("remediation") or "")[:200])
