# Apply HD Homes Auth email templates to hosted Supabase (Management API).
# Requires: SUPABASE_ACCESS_TOKEN from https://supabase.com/dashboard/account/tokens
# Usage (PowerShell):
#   $env:SUPABASE_ACCESS_TOKEN = "sbp_..."
#   $env:PROJECT_REF = "wbonjdqsifwsawhhxygl"   # optional
#   python scripts/apply_auth_email_templates.py

from __future__ import annotations

import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
TEMPLATES = ROOT / "supabase" / "templates"
PROJECT_REF = os.environ.get("PROJECT_REF", "wbonjdqsifwsawhhxygl")
TOKEN = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()

TEMPLATE_MAP = {
    "confirm_signup.html": (
        "mailer_subjects_confirmation",
        "mailer_templates_confirmation_content",
        "Confirm your HD Homes email",
    ),
    "recovery.html": (
        "mailer_subjects_recovery",
        "mailer_templates_recovery_content",
        "Reset your HD Homes password",
    ),
    "invite.html": (
        "mailer_subjects_invite",
        "mailer_templates_invite_content",
        "You are invited to HD Homes",
    ),
    "magic_link.html": (
        "mailer_subjects_magic_link",
        "mailer_templates_magic_link_content",
        "Your HD Homes sign-in link",
    ),
    "email_change.html": (
        "mailer_subjects_email_change",
        "mailer_templates_email_change_content",
        "Confirm your new HD Homes email",
    ),
    "reauthentication.html": (
        "mailer_subjects_reauthentication",
        "mailer_templates_reauthentication_content",
        "Confirm it is you — HD Homes",
    ),
}


def main() -> int:
    if not TOKEN:
        print(
            "Missing SUPABASE_ACCESS_TOKEN.\n"
            "1) Open https://supabase.com/dashboard/account/tokens\n"
            "2) Create a token\n"
            "3) In PowerShell: $env:SUPABASE_ACCESS_TOKEN='sbp_...'\n"
            "4) Re-run: python scripts/apply_auth_email_templates.py",
            file=sys.stderr,
        )
        return 1

    payload: dict[str, str] = {}
    for filename, (subject_key, content_key, subject) in TEMPLATE_MAP.items():
        path = TEMPLATES / filename
        if not path.exists():
            print(f"Missing template file: {path}", file=sys.stderr)
            return 1
        payload[subject_key] = subject
        payload[content_key] = path.read_text(encoding="utf-8")

    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/config/auth"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        method="PATCH",
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            body = res.read().decode("utf-8", errors="replace")
            print(f"OK HTTP {res.status} — Auth email templates updated for {PROJECT_REF}")
            if body:
                print(body[:500])
            return 0
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        print(f"Failed HTTP {e.code}: {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
