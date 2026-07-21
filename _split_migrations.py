from pathlib import Path

def strip_transaction(sql: str) -> str:
    lines = []
    for line in sql.splitlines():
        s = line.strip()
        if s in ("BEGIN;", "COMMIT;"):
            continue
        lines.append(line)
    return "\n".join(lines).strip() + "\n"


def chunk_file(path: str, ranges: list[tuple[str, int, int]]) -> dict[str, str]:
    text = Path(path).read_text(encoding="utf-8")
    lines = text.splitlines()
    out = {}
    for name, start, end in ranges:
        chunk = "\n".join(lines[start - 1 : end])
        out[name] = strip_transaction(chunk)
    return out


hcm_ranges = [
    ("human_capital_management_p1_permissions_tables", 17, 644),
    ("human_capital_management_p2_seeds", 645, 1027),
    ("human_capital_management_p3_rls_realtime", 1029, 1364),
]

eoc_ranges = [
    ("enterprise_operations_center_p1_permissions_tables", 21, 541),
    ("enterprise_operations_center_p2_seeds", 543, 767),
    ("enterprise_operations_center_p3_rls_realtime", 769, 1123),
]

for label, ranges, src in [
    ("hcm", hcm_ranges, "supabase/migrations/20260714200000_human_capital_management_system.sql"),
    ("eoc", eoc_ranges, "supabase/migrations/20260714210000_enterprise_operations_center.sql"),
]:
    chunks = chunk_file(src, ranges)
    for name, sql in chunks.items():
        out = Path(f"_apply_chunks/{name}.sql")
        out.parent.mkdir(exist_ok=True)
        out.write_text(sql, encoding="utf-8")
        print(name, len(sql))
