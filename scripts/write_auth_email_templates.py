"""Write the six Supabase Auth HTML templates in the HD Homes master layout."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "supabase" / "templates"
LOGO = "https://wbonjdqsifwsawhhxygl.supabase.co/storage/v1/object/public/logos/hd_homes_logo.png"

PAGES = {
    "confirm_signup.html": (
        "Confirm your HD Homes email",
        "Account",
        "Welcome to HD Homes",
        "Thank you for creating an account with <strong style=\"color:#111111;\">HD Homes Limited</strong>.",
        "Please confirm your email address to activate your account.",
        "Confirm My Email",
        "{{ .ConfirmationURL }}",
        True,
    ),
    "recovery.html": (
        "Reset your HD Homes password",
        "Account security",
        "Reset your password",
        "We received a request to reset the password for your HD Homes account.",
        "Use the button below. If you did not request this, you can ignore this email.",
        "Reset password",
        "{{ .ConfirmationURL }}",
        False,
    ),
    "invite.html": (
        "You are invited to HD Homes",
        "Invitation",
        "You're invited to join HD Homes",
        "You have been invited to join <strong style=\"color:#111111;\">HD Homes Limited</strong>.",
        "Use the button below to accept your invitation and create your account.",
        "Accept invitation",
        "{{ .ConfirmationURL }}",
        False,
    ),
    "magic_link.html": (
        "Your HD Homes sign-in link",
        "Sign in",
        "Sign in to HD Homes",
        "Use this secure link to sign in to your HD Homes account.",
        "The link expires shortly. If you did not request it, you can ignore this email.",
        "Sign in",
        "{{ .ConfirmationURL }}",
        False,
    ),
    "email_change.html": (
        "Confirm your new HD Homes email",
        "Account security",
        "Confirm your new email",
        "Confirm <strong style=\"color:#111111;\">{{ .NewEmail }}</strong> to finish updating your HD Homes account.",
        "If you did not request this change, you can ignore this email.",
        "Confirm new email",
        "{{ .ConfirmationURL }}",
        False,
    ),
    "reauthentication.html": (
        "Confirm it is you",
        "Account security",
        "Confirm it is you",
        "For your security, confirm this action on your HD Homes account.",
        "Your code is <strong style=\"color:#111111;\">{{ .Token }}</strong>.",
        "",
        "",
        False,
    ),
}

SHELL = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <style>
    @media only screen and (max-width: 600px) {{
      .email-wrapper {{ padding: 20px 12px !important; }}
      .email-card {{ width: 100% !important; border-radius: 12px !important; }}
      .content {{ padding: 32px 24px !important; }}
      .heading {{ font-size: 26px !important; }}
      .button {{ width: 100% !important; box-sizing: border-box !important; }}
    }}
  </style>
</head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;color:#1a1a1a;">
<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f3f4f6;">
  <tr>
    <td align="center" class="email-wrapper" style="padding:45px 16px;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" class="email-card" style="max-width:620px;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb;">
        <tr>
          <td align="center" style="background:#111111;padding:32px 25px 28px;">
            <img src="{logo}" alt="HD Homes Limited" width="95" style="display:block;max-width:95px;height:auto;margin:0 auto;border:0;">
            <p style="margin:14px 0 0;font-size:11px;letter-spacing:2.5px;color:#d6a847;font-weight:bold;">HD HOMES LIMITED</p>
          </td>
        </tr>
        <tr><td style="height:4px;background:#d6a847;font-size:0;line-height:0;">&nbsp;</td></tr>
        <tr>
          <td class="content" style="padding:48px 50px 42px;">
            <p style="margin:0 0 12px;font-size:13px;font-weight:bold;letter-spacing:1.5px;text-transform:uppercase;color:#b0842f;">{eyebrow}</p>
            <h1 class="heading" style="margin:0 0 22px;font-size:30px;line-height:1.25;font-weight:700;color:#111111;">{heading}</h1>
            <p style="margin:0 0 18px;font-size:16px;line-height:1.7;color:#4b5563;">{lead}</p>
            <p style="margin:0 0 30px;font-size:16px;line-height:1.7;color:#4b5563;">{body}</p>
            {cta}
            {note}
          </td>
        </tr>
        <tr><td style="padding:0 50px;"><div style="height:1px;background:#eeeeee;"></div></td></tr>
        <tr>
          <td align="center" style="padding:30px 30px 34px;background:#ffffff;">
            <p style="margin:0 0 8px;font-size:14px;font-weight:bold;color:#222222;">HD Homes Limited</p>
            <p style="margin:0 0 18px;font-size:12px;line-height:1.6;color:#8a8a8a;">Making Quality Housing Accessible</p>
            <p style="margin:0;font-size:11px;line-height:1.6;color:#a0a0a0;">This is an automated message from HD Homes Limited. Please do not reply directly to this email.</p>
            <p style="margin:14px 0 0;font-size:11px;color:#b0b0b0;">&copy; HD Homes Limited. All rights reserved.</p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
"""

NOTE = """<div style="background:#f3f4f6;border-radius:10px;padding:16px 18px;margin-top:28px;">
<p style="margin:0 0 4px;font-size:14px;font-weight:700;color:#111111;">Didn't create this account?</p>
<p style="margin:0;font-size:14px;line-height:1.5;color:#6b7280;">You can safely ignore this email. No action is required.</p>
</div>"""


def cta_block(label: str, href: str) -> str:
    if not label or not href:
        return ""
    return (
        '<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center">'
        f'<a href="{href}" class="button" style="display:inline-block;background:#d6a847;color:#111111;'
        'text-decoration:none;font-size:16px;font-weight:bold;padding:16px 34px;border-radius:8px;'
        f'min-width:210px;text-align:center;">{label}</a>'
        "</td></tr></table>"
        '<p style="margin:30px 0 0;font-size:12px;line-height:1.6;color:#9ca3af;text-align:center;">'
        "If the button does not work, open HD Homes or contact support.</p>"
    )


def main() -> None:
    for name, (title, eyebrow, heading, lead, body, label, href, note) in PAGES.items():
        html = SHELL.format(
            title=title,
            logo=LOGO,
            eyebrow=eyebrow,
            heading=heading,
            lead=lead,
            body=body,
            cta=cta_block(label, href),
            note=NOTE if note else "",
        )
        (ROOT / name).write_text(html, encoding="utf-8")
        if href:
            assert href in html
        assert "localhost" not in html
        print(name)


if __name__ == "__main__":
    main()
