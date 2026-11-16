# Changelog

## 8.10.2-2 (2026-11-16)

- README: Deploy on Railway button for the published template `suitecrm-1`. No change to the app or its image.
- Start script (already on `main` before publishing): removes the duplicate Apache MPM that Railway's build brings back (AH00534), and the first-boot page answers 503 so the health check waits for SuiteCRM.

## 8.10.2-1 (2026-11-16)

First version of the template.

- SuiteCRM 8.10.2 on `php:8.3.36-apache-bookworm@sha256:a14446c32a3c8aeb9b4dac7fb73b03dfd8006e670d9b43ea7947e4030d3cbae6`.
- MariaDB 11.4.13 (`mariadb:11.4.13@sha256:5e73baf8179b29f115101bb102763a47a017361f3e9792daccba6646c3ab1532`).
- Unattended first install through the official CLI installer, generated admin password, scheduler loop, `site_url` kept on the Railway domain.
