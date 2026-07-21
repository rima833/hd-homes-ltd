import json
import pathlib
import sys

chunk = sys.argv[1]
name = sys.argv[2]
src = pathlib.Path(r"C:\Users\Shamah\Documents\FlutterProjects\hdhomesproject\_apply_chunks") / chunk
text = src.read_text(encoding="utf-8")
payload = {
    "project_id": "wbonjdqsifwsawhhxygl",
    "name": name,
    "query": text,
}
out = src.with_suffix(".payload.json")
out.write_text(json.dumps(payload), encoding="utf-8")
print(out)
print(len(text))
