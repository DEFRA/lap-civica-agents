# Graph API Send Mail Skill

Purpose: provide a single callable skill to send email via Microsoft Graph API.

Signature
---------

- `send_mail(tenant_id, client_id, client_secret, sender, to, subject, body, content_type='HTML', cc=None, bcc=None, attachments=None, save_to_sent=True)`

Parameters
----------

- `tenant_id` (str): Azure AD tenant id
- `client_id` (str): App (client) id
- `client_secret` (str): App client secret (sensitive)
- `sender` (str): userPrincipalName or id to send mail as (e.g. `no-reply@example.com`)
- `to` (List[str]): recipient email addresses
- `subject` (str): subject line
- `body` (str): message body
- `content_type` (str): `HTML` or `Text` (default `HTML`)
- `cc` (List[str] | None): CC recipients
- `bcc` (List[str] | None): BCC recipients
- `attachments` (List[dict] | None): attachments where each dict contains keys: `name` (str), `bytes_base64` (str base64-encoded)
- `save_to_sent` (bool): save the message to Sent Items (default True)

Return
------

Dictionary with keys:

- `success` (bool)
- `status_code` (int) — HTTP return code from Graph
- `response` (dict|string) — parsed JSON response if available
- `error` (str|null) — human-friendly error message

Error handling
--------------

The implementation raises no uncaught exceptions. All expected failure modes are returned in the `error` field and `success` is set to `False`. Errors covered include:

- Authentication errors from MSAL
- Network errors (requests exceptions)
- Graph API 4xx/5xx responses (returned body is included when available)
- Attachment encoding/size validation errors

CLI
---

The skill ships with a small CLI wrapper implemented in `graph_api_send_mail.py` for manual testing. Use the requirements file to install dependencies.
