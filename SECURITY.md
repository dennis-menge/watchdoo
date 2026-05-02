# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, **please do not open a public issue**.

Instead, report it privately via GitHub's [Security Advisories](../../security/advisories/new) feature, or contact the maintainer directly.

We will acknowledge the report within a reasonable time frame and provide a fix or mitigation as soon as possible.

## Threat Model

This project is a **self-hosted** companion to an unofficial Cookidoo API. Each user runs their own backend instance with their own credentials.

### What's in scope

- **Credential leakage** through logs, error messages, or unintentional exposure
- **Authentication bypass** on the `/api/v1/*` endpoints (the `X-API-Key` middleware)
- **Token storage** — Cookidoo tokens are held in process memory by `cookidoo-api`; ensure they are not persisted to disk in any new code paths
- **Container hardening** issues in the provided `Dockerfile`
- **Watch ↔ Backend transport** — only HTTPS should be used in production; the iOS companion app must transmit the API key securely via WatchConnectivity (already encrypted by the system)

### What's out of scope

- Vulnerabilities in upstream dependencies (please report to the respective project)
  - [`cookidoo-api`](https://github.com/miaucl/cookidoo-api)
  - [`fastapi`](https://github.com/tiangolo/fastapi)
- Issues caused by users committing secrets to their fork (use `.env`, never hard-code)
- Misuse of the Cookidoo API that violates Vorwerk's Terms of Service — see the project disclaimer

## Hardening Checklist for Self-Hosters

- [ ] `API_KEY` is generated with `openssl rand -hex 32` (32+ random bytes)
- [ ] `.env` is **not** committed to your fork
- [ ] Backend is exposed only over HTTPS (Azure Container Apps does this by default)
- [ ] Backend is not publicly indexed/exposed beyond what's needed for your Watch
- [ ] Logs do not contain credentials (`LOG_LEVEL=INFO` by default; avoid `DEBUG` in production)
