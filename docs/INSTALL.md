# tsPanel Installation Guide

English | [Tiếng Việt](HUONG-DAN-SU-DUNG.md#2-cài-đặt)

This guide covers installing, upgrading, operating, and removing tsPanel. For a short overview, see the [README](../README.md).

- [System requirements](#system-requirements)
- [Install](#install)
- [After installation](#after-installation)
- [Installer options](#installer-options)
- [Install a specific version](#install-a-specific-version)
- [Use an existing PostgreSQL server](#use-an-existing-postgresql-server)
- [Offline installation](#offline-installation)
- [Verify a release](#verify-a-release)
- [Upgrade](#upgrade)
- [Admin commands](#admin-commands)
- [File locations](#file-locations)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)

---

## System requirements

| Item | Requirement |
| --- | --- |
| Operating system | Ubuntu 22.04 / 24.04, Debian 12, Rocky Linux 9, AlmaLinux 9 |
| Architecture | `x86_64` (amd64) or `aarch64` (arm64) |
| Privileges | `root` or an account with `sudo` |
| Init system | `systemd` |
| Resources | At least 1 vCPU and 1 GB RAM. Use 2 GB RAM or more if you run MySQL/MariaDB or several applications |
| Network | Access to `github.com` and `raw.githubusercontent.com`. The panel port (default `8888/TCP`) must be reachable |
| Tools | `curl` or `wget`, `tar`, `sha256sum` (present on most distributions) |

Install on a **fresh server**. Do not install alongside aaPanel, BT Panel, or any other panel that uses `/www`.

The panel stores its data in **PostgreSQL 14 or later**, and the installer sets up PostgreSQL for you. Ubuntu 20.04 and Debian 11 only ship PostgreSQL versions older than 14, so the installer stops on those systems. On those systems, [use an existing PostgreSQL server](#use-an-existing-postgresql-server).

---

## Install

Run on the server:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash
```

Without `curl`:

```bash
wget -qO- https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash
```

If you are logged in as `root`, you can drop `sudo`.

The installer:

1. Checks the environment: root privileges, Linux, systemd, and CPU architecture.
2. Downloads the latest release from [GitHub Releases](https://github.com/techshield-tech/tsPanel/releases) and verifies its signature and checksum.
3. Installs PostgreSQL (with `apt` or `dnf`/`yum`) and creates a `tspanel` database and user with a random password.
4. Installs the panel to `/www/server/tspanel`, creates the `tspanel` systemd service and the `ts` admin command.
5. If `ufw` or `firewalld` is active, opens the panel port and port `8889/TCP` (used by node agents).
6. Generates a password for the `admin` account and prints the login details.

When it finishes, you see:

```text
=== tsPanel installed ===
Panel URL:    https://203.0.113.10:8888/
Username:     admin
Password:     xxxxxxxxxxxxxxxxxxxx
Entrance:     https://203.0.113.10:8888/xxxxxxxx   (the only URL that opens the panel; save it)
```

> [!IMPORTANT]
> **Save the password and the `Entrance` URL now.** They are shown only once. `Entrance` is the private login URL: a browser that is not signed in can only open the panel through it. If you lose either one, see [Admin commands](#admin-commands).

> [!NOTE]
> - The panel uses a self-signed HTTPS certificate by default, so your browser shows a warning on the first visit. You can upload a valid certificate in **Settings → General → Panel HTTPS certificate**.
> - On a cloud server (AWS, GCP, Azure, Vultr, DigitalOcean, …), also open port `8888/TCP` in the provider's security group or firewall.

---

## After installation

1. Open the `Entrance` URL and sign in as `admin`.
2. On the first sign-in, the panel suggests a software bundle to install (Nginx, MySQL, PHP, …). A fresh install has **no software preinstalled**. Application deployment needs Nginx (OpenResty) and Docker.
3. Go to **Settings → General → Security** to change the password and enable two-factor authentication.
4. Set up alert channels (**Settings → Alerts**) and automatic backups (**Settings → Backup**).

### Software from the App Store

The **App Store** installs Nginx (OpenResty), MySQL, MariaDB, PostgreSQL, Redis, Memcached, PHP 7.4 and 8.1–8.4, Pure-FTPd, phpMyAdmin, Python and Go version managers, and more.

- These are **prebuilt packages** downloaded from `https://dl.mmoall.com`. Nothing is compiled on your server.
- Before installing, the panel checks each package's SHA-256 checksum and ed25519 signature.
- The packages need glibc 2.31 or later.
- The current package list is in [`index.json`](https://dl.mmoall.com/index.json).

The WAF (web application firewall) is delivered as a plugin and requires Nginx (OpenResty).

---

## Installer options

Pass options to the installer with `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash -s -- --port 9999
```

Or use environment variables. Put them **after** `sudo`:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo TSPANEL_PORT=9999 bash
```

| Option | Environment variable | Description |
| --- | --- | --- |
| `--version X` | `TSPANEL_VERSION` | Install a specific version, for example `0.1.0-beta.1`. Defaults to the latest |
| `--port N` | `TSPANEL_PORT` | Panel port, default `8888`. Applies to new installs only |
| `--db-url URL` | `TSPANEL_DATABASE_URL` | Use an existing PostgreSQL server and skip installing PostgreSQL |
| `--tarball PATH` | `TSPANEL_TARBALL` | Install from a local tarball instead of downloading |
| `--insecure` | — | With `--tarball`: skip all verification. Only use with a tarball you have checked yourself |
| `--repo owner/name` | `TSPANEL_REPO` | Repository that hosts the releases, default `techshield-tech/tsPanel` |
| `--no-firewall` | — | Do not change `ufw`/`firewalld` |
| `--skip-db-backup` | — | When upgrading, do not back up the panel database first |
| `-y` | — | Do not ask for confirmation |
| `-h`, `--help` | — | Show help |

## Install a specific version

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash -s -- --version 0.1.0-beta.1
```

All versions are listed on the [Releases](https://github.com/techshield-tech/tsPanel/releases) page.

## Use an existing PostgreSQL server

This needs PostgreSQL **14 or later**. First, create a user and a database for the panel:

```bash
sudo -u postgres psql -c "CREATE ROLE tspanel WITH LOGIN PASSWORD 'change-this-password'"
sudo -u postgres psql -c "CREATE DATABASE tspanel OWNER tspanel"
```

Then install with `--db-url`:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh \
  | sudo bash -s -- --db-url 'postgres://tspanel:change-this-password@127.0.0.1:5432/tspanel?sslmode=disable'
```

## Offline installation

Use this when the server cannot download from GitHub.

1. On another machine, download these files from [Releases](https://github.com/techshield-tech/tsPanel/releases) (`<arch>` is `amd64` or `arm64`):
   - `install.sh`
   - `tspanel-<version>-linux-<arch>.tar.gz`
   - `SHA256SUMS` and `SHA256SUMS.sig` (signature check), **or** `tspanel-<version>-linux-<arch>.tar.gz.sha256` (integrity check only)
2. Copy them all into **one directory** on the server.
3. Run the installer:

   ```bash
   sudo bash install.sh --tarball tspanel-0.1.0-beta.1-linux-amd64.tar.gz
   ```

The server still needs to install PostgreSQL with `apt`/`dnf`. If it cannot, add `--db-url`.

## Verify a release

Every release includes a `SHA256SUMS` file. To check downloaded files yourself, put `SHA256SUMS` in the same directory and run:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

The installer also verifies the ed25519 signature in `SHA256SUMS.sig` automatically.

---

## Upgrade

Click **Update** in the panel's top bar, or run the installer again:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash
```

When the installer finds `/www/server/tspanel/config.yaml`, it switches to **upgrade** mode:

1. Backs up the panel database with `pg_dump` (skipped with `--skip-db-backup`).
2. Stops the service and keeps the old binary as `tspanel.bak`.
3. Replaces the binary and starts the service.
4. If the new version fails to start, it **rolls back** to the old binary and restores the database.

Configuration, database, and port are kept. To upgrade to a specific version, add `--version X`. To see the running version, use `ts version`.

---

## Admin commands

The `ts` command is installed at `/usr/local/bin/ts`. Run these as `root` or with `sudo`.

| Command | Action |
| --- | --- |
| `ts version` | Show the panel version |
| `ts reset-password admin` | Set a new random password for `admin` |
| `ts entrance show` | Show the private login URL and whether it is enabled |
| `ts entrance disable` | Disable the private login URL (if you lost it or it is blocked) |
| `ts migrate` | Run panel database migrations |
| `ts uninstall` | Uninstall the panel |

Service management:

```bash
systemctl status tspanel      # status
systemctl restart tspanel     # restart
journalctl -u tspanel -f      # follow logs
```

---

## File locations

| Path | Contents |
| --- | --- |
| `/www/server/tspanel/tspanel` | Panel binary |
| `/www/server/tspanel/config.yaml` | Configuration: port, database connection, … |
| `/www/server/tspanel/data/` | Panel data. Logs are in `data/logs/` (`panel.log`, `error.log`); database backups taken during upgrades are in `data/db-backups/` |
| `/usr/local/bin/ts` | Admin command |
| `/etc/systemd/system/tspanel.service` | systemd service |
| `/www/server/` | Software installed from the panel |
| `/www/wwwroot/` | Website source code |
| `/www/wwwlogs/` | Website logs |
| `/www/backup/` | Database and directory backups |

**Change the panel port:** use **Settings → General → Panel port → Change port**. Or edit `listenAddr` in `/www/server/tspanel/config.yaml` (for example `listenAddr: ":9999"`), run `systemctl restart tspanel`, and open the new port in your firewall.

---

## Troubleshooting

| Problem | Solution |
| --- | --- |
| Cannot open the panel | Make sure you are using the `Entrance` URL. Check the service with `systemctl status tspanel` and that the port is listening with `ss -ltnp \| grep 8888`. Check your cloud provider's firewall too |
| Browser certificate warning | The panel uses a self-signed certificate. Upload a valid one in **Settings → General → Panel HTTPS certificate** |
| Forgot the password | `sudo ts reset-password admin` |
| Lost the private login URL | Show it with `sudo ts entrance show`, or disable it with `sudo ts entrance disable` |
| `PostgreSQL server version is too old` | The OS ships PostgreSQL older than 14. Install PostgreSQL 14+ from [postgresql.org](https://www.postgresql.org/download/), then reinstall with `--db-url` |
| `unsupported distribution for automatic PostgreSQL setup` | Install PostgreSQL 14+ yourself, then reinstall with `--db-url` |
| `checksum mismatch` | The download is corrupt or incomplete. Run the installer again |
| Service does not start | Check `journalctl -u tspanel -n 200 --no-pager` and `/www/server/tspanel/data/logs/error.log` |

Problems with panel features (deployment, domains, MCP, …) are covered in the [User Guide](HUONG-DAN-SU-DUNG.md#19-xử-lý-sự-cố) (Vietnamese).

---

## Uninstall

> [!CAUTION]
> `/www` holds your websites, logs, and backups. Back up anything you need before deleting it.

1. Uninstall software installed through the panel (Nginx, MySQL, PHP, …) from the **App Store** first. Removing tsPanel does not remove it.
2. Remove the panel with `sudo ts uninstall`, or manually:

   ```bash
   sudo systemctl disable --now tspanel
   sudo rm -f /etc/systemd/system/tspanel.service /usr/local/bin/ts
   sudo systemctl daemon-reload
   sudo rm -rf /www/server/tspanel
   ```

3. If the installer set up PostgreSQL and you want to remove the panel database:

   ```bash
   sudo -u postgres psql -c "DROP DATABASE IF EXISTS tspanel"
   sudo -u postgres psql -c "DROP ROLE IF EXISTS tspanel"
   ```
