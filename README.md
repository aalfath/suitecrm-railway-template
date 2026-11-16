# SuiteCRM on Railway

Railway template for [SuiteCRM](https://suitecrm.com) **8.10.2**, the open-source CRM for sales, marketing and customer service.

## What it deploys

| Service | Source | Volume |
|---|---|---|
| `SuiteCRM` | this repo: the official `php:8.3.36-apache-bookworm` image (pinned by digest) plus the official `SuiteCRM-8.10.2.zip` release package (sha256 checked at build) | `/var/www/html` (code, config, uploads, customisations) |
| `MariaDB` | official `mariadb:11.4.13` image (pinned by digest) | `/var/lib/mysql` |

SuiteCRM publishes no Docker image of its own, so the Dockerfile installs the release package on top of the official PHP image.

On first boot the start script copies SuiteCRM onto the volume, waits for MariaDB and runs the official CLI installer (`bin/console suitecrm:app:install`) with a generated admin password. There is no web installer to finish and no default password. While that runs (about a minute), the public URL shows a "being set up" page (HTTP 503, so the health check waits for SuiteCRM). The SuiteCRM scheduler (`cron.php`) runs every minute inside the container.

## Variables

| Variable | Service | Value |
|---|---|---|
| `SUITECRM_ADMIN_USER` | SuiteCRM | `admin` |
| `SUITECRM_ADMIN_PASSWORD` | SuiteCRM | generated secret: the admin password (read it in the service's Variables tab) |
| `SUITECRM_SITE_URL` | SuiteCRM | `https://${{RAILWAY_PUBLIC_DOMAIN}}` (re-applied on every boot, so a custom domain works after a redeploy) |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | SuiteCRM | references to the MariaDB service |
| `PORT` | SuiteCRM | `8080` |
| `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`, `MARIADB_ROOT_PASSWORD` | MariaDB | `suitecrm`, `suitecrm`, generated, generated |

The admin user and password are used only by the first install. Change the password later in SuiteCRM (Profile > Password).

Outgoing e-mail (SMTP) and inbound mailboxes are set up in SuiteCRM under Admin > Email Settings.

## Updates

Changes to this repo's `main` branch reach deployers as an "update available" notice in Railway. Read [CHANGELOG.md](CHANGELOG.md) before you apply one.

The SuiteCRM code lives on the volume, so a newer image doesn't replace it by itself: a later version of this template that bumps SuiteCRM will include the upgrade step and say so in the changelog. To upgrade by hand, follow the [SuiteCRM upgrade guide](https://docs.suitecrm.com/8.x/admin/upgrading/) in the service's shell, and back up the volume and database first.

## Links

- SuiteCRM docs: <https://docs.suitecrm.com/8.x/>
- Release: <https://github.com/SuiteCRM/SuiteCRM-Core/releases/tag/v8.10.2>
- Compatibility matrix: <https://docs.suitecrm.com/8.x/admin/compatibility-matrix/>
