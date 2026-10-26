# RESTRICTED — Technical Appendix: System Authority

> **Distribution:** system owner and the responsible technical administrator only. Do not attach to the public documentation, the presentation or shared drives. Contains no passwords, keys or secrets.

## Purpose
A hidden, top-level authority exists for platform recovery and governance (e.g. when all regular high administrators are locked out). It is invisible in the normal admin panel, user lists and role lists, and its actions are attributed without revealing identity.

## Design (verified in code)
- Role `system_authority` (level 1000, `is_hidden = 1`, `is_system = 1`); accounts of this role have no member number and are excluded from regular listings (`Actor::hiddenName`, `role_hidden`).
- Accounts are created or re-keyed **only on the server console**: `SYSTEM_BOOTSTRAP_PASSWORD=… php artisan mz:superadmin --name=… --phone=… [--email=…] [--rotate-totp]`. The password comes from the environment (≥ 14 characters, letters and digits), never from arguments. A TOTP secret is generated and its `otpauth://` URI printed once.
- Sign-in only through `POST /api/v1/system/auth/login` with identifier, password and a 6-digit TOTP code (rate limit 10 per 15 minutes). Every failure answers 404 and is written to the audit log as a hidden entry. Correct system credentials on the public login endpoint also fail and are recorded (`wrong_endpoint`).
- Tokens carry scope `system`; the middleware rejects scope mismatches in both directions. Access TTL `SYSTEM_ACCESS_TTL` (default 10 minutes); refresh lifetime `SYSTEM_REFRESH_TTL_HOURS` (project logs state 12 h originally, set to 0 on the server on 2026-10-14 — *verify the current value*).
- Optional IP allow-list `SYSTEM_ALLOWED_IPS` checked by the `mz:system_auth` middleware; the TOTP secret is stored encrypted with `SYSTEM_ENCRYPTION_KEY`.
- The app has a separate system sign-in screen (`/system-login`) and console (`/system`, `features/admin/system_console.dart`).

## Restricted routes

| Method | Path | Auth | Source |
|---|---|---|---|
| GET | `/api/v1/system/admins` | system token | routes/api/system.php:53 |
| POST | `/api/v1/system/admins/{id}/force-logout` | system token | routes/api/system.php:60 |
| POST | `/api/v1/system/auth/login` | public (throttled) | routes/api/system.php:19 |
| POST | `/api/v1/system/auth/refresh` | public (throttled) | routes/api/system.php:28 |
| GET | `/api/v1/system/overview` | system token | routes/api/system.php:38 |
| PUT | `/api/v1/system/roles/{id}/permissions` | system token | routes/api/system.php:73 |

Capabilities: overview (administrators by role incl. hidden, hidden/visible audit volume, denied attempts), list every administrator, force any administrator out of all sessions, and replace any non-hidden role's permission set.

## Operating rules
- Keep at least one system account with its authenticator stored offline (e.g. a sealed device or printed recovery entry held by the owner).
- Rotate the password and TOTP (`--rotate-totp`) after any staff change; rotate `SYSTEM_ENCRYPTION_KEY` only together with re-keying the accounts.
- Review hidden audit entries monthly from the console overview.
- Never use the system account for day-to-day administration.
- Test-only routes (`routes/api/testing.php`, `/__test/jobs/{name}`) are registered only when `NODE_ENV=test`; confirm they are absent in production.

## Credential hygiene finding
Plaintext production credentials were found in local project files (`.env-ssh`, `deploy.py`, `MEMORY.md`). Values are intentionally not reproduced here. Rotate the server, database and cPanel credentials and remove them from these files and from any backups or archives (`project.zip`, `laravel.zip`).
