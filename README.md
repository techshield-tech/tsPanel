# tsPanel

[![Release](https://img.shields.io/github/v/release/techshield-tech/tsPanel?include_prereleases&label=release)](https://github.com/techshield-tech/tsPanel/releases)

tsPanel là panel quản trị máy chủ Linux qua trình duyệt, do [TechShield](https://techshield.vn) phát triển. Panel gồm các chức năng: triển khai ứng dụng bằng container, website (Nginx/OpenResty, PHP, Node.js, Python, Go), cơ sở dữ liệu, DNS và SSL, Docker, tường lửa ứng dụng web (WAF), tác vụ định kỳ, sao lưu, giám sát, quản lý tệp, terminal web và quản lý nhiều máy chủ. Panel cũng có máy chủ MCP để trợ lý AI tạo và triển khai dự án. Toàn bộ panel được đóng gói trong một file chạy duy nhất.

> [!NOTE]
> tsPanel đang ở giai đoạn **beta**. Hãy chạy thử trên máy chủ mới hoặc máy thử nghiệm trước khi dùng cho môi trường production.

![tsPanel](docs/images/01-home.png)

**Tài liệu:** [Hướng dẫn sử dụng](docs/HUONG-DAN-SU-DUNG.md)

---

## Tính năng

| Nhóm | Chức năng |
| --- | --- |
| Triển khai | Build và chạy ứng dụng trong container, lấy mã nguồn từ Git, tệp zip, thư mục trên máy chủ hoặc Docker image. Tự triển khai lại khi có push, gắn tên miền, cấp HTTPS Let's Encrypt, khai báo biến môi trường, xem log build và log runtime, rollback |
| AI / MCP | Endpoint MCP cho Claude Code, Claude Desktop, Cursor, VS Code, Windsurf, Codex CLI, Gemini CLI. Khoá API có giới hạn quyền, dự án, IP và thời hạn |
| Website | Dự án PHP hoặc web tĩnh, Node.js, Python, Go, reverse proxy |
| Cơ sở dữ liệu | MySQL/MariaDB, PostgreSQL, MongoDB, Redis, SQL Server, cả trên máy chủ này lẫn máy chủ từ xa |
| Tên miền | Kết nối nhà cung cấp DNS (Cloudflare, …), quản lý bản ghi, chứng chỉ Let's Encrypt (kể cả wildcard), tự gia hạn |
| Docker | Container, image, Compose, mạng, volume, registry, ứng dụng một chạm, cấu hình daemon |
| WAF | Coraza + OWASP CRS, kiểm soát truy cập, giới hạn tốc độ, chặn theo quốc gia, quy tắc tuỳ chỉnh, nhật ký và bản đồ tấn công |
| Vận hành | Giám sát tài nguyên, nhật ký kiểm toán, log hệ thống, log đăng nhập SSH, tác vụ định kỳ, sao lưu, cảnh báo qua Email/Telegram/Webhook |
| Tiện ích | Trình quản lý tệp, trình soạn thảo, terminal web, FTP |
| Nhiều máy chủ | Quản lý node qua agent kết nối ngược về master |
| Bảo mật panel | URL đăng nhập riêng, xác thực hai lớp, HTTP Basic Auth, cảnh báo đăng nhập, chứng chỉ HTTPS cho panel |

<table>
  <tr>
    <td width="50%"><img src="docs/images/27-deploy-projects.png" alt="Triển khai – Dự án"><br>Triển khai – Danh sách dự án</td>
    <td width="50%"><img src="docs/images/29-deploy-project-overview.png" alt="Triển khai – Chi tiết dự án"><br>Triển khai – Chi tiết dự án</td>
  </tr>
  <tr>
    <td><img src="docs/images/36-deploy-mcp-overview.png" alt="AI / MCP"><br>AI / MCP</td>
    <td><img src="docs/images/44-waf-overview.png" alt="WAF"><br>WAF</td>
  </tr>
</table>

---

## Yêu cầu hệ thống

| Mục | Yêu cầu |
| --- | --- |
| Hệ điều hành | Ubuntu 22.04 / 24.04, Debian 12, Rocky Linux / AlmaLinux 9 |
| Kiến trúc | `x86_64` (amd64) hoặc `aarch64` (arm64) |
| Quyền | `root` hoặc tài khoản có `sudo` |
| Hệ thống init | `systemd` |
| Tài nguyên | Tối thiểu 1 vCPU, 1 GB RAM. Nếu chạy MySQL/MariaDB hoặc nhiều ứng dụng thì nên có từ 2 GB RAM |
| Mạng | Truy cập được `github.com` và `raw.githubusercontent.com`. Mở cổng panel (mặc định `8888/TCP`) |
| Công cụ | `curl` hoặc `wget`, `tar`, `sha256sum` (hầu hết bản phân phối đã có sẵn) |

Nên cài trên **máy chủ mới**. Không cài chung với aaPanel, BT Panel hay panel khác cũng dùng thư mục `/www`.

Panel lưu dữ liệu trong **PostgreSQL 14 trở lên**, và script cài đặt sẽ tự cài PostgreSQL. Ubuntu 20.04 và Debian 11 chỉ có PostgreSQL cũ hơn bản 14 nên script sẽ dừng lại. Với các hệ điều hành này, hãy [dùng PostgreSQL có sẵn](#dùng-postgresql-có-sẵn).

---

## Cài đặt nhanh

Chạy lệnh sau trên máy chủ:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash
```

Nếu máy không có `curl`:

```bash
wget -qO- https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash
```

Nếu đang đăng nhập bằng `root`, có thể bỏ `sudo`.

Script cài đặt sẽ lần lượt:

1. Kiểm tra môi trường: quyền root, Linux, systemd và kiến trúc CPU.
2. Tải bản phát hành mới nhất từ [GitHub Releases](https://github.com/techshield-tech/tsPanel/releases) và kiểm tra tính toàn vẹn.
3. Cài PostgreSQL (qua `apt` hoặc `dnf`/`yum`), rồi tạo database và user `tspanel` với mật khẩu ngẫu nhiên.
4. Cài panel vào `/www/server/tspanel`, tạo service systemd `tspanel` và lệnh quản trị `ts`.
5. Nếu `ufw`/`firewalld` đang bật, mở cổng panel và cổng `8889/TCP` (cổng của agent node).
6. Tạo mật khẩu cho tài khoản `admin` và in ra thông tin đăng nhập.

Khi cài xong, màn hình hiện:

```text
=== tsPanel installed ===
Panel URL:    https://203.0.113.10:8888/
Username:     admin
Password:     xxxxxxxxxxxxxxxxxxxx
Entrance:     https://203.0.113.10:8888/xxxxxxxx   (the only URL that opens the panel; save it)
```

> [!IMPORTANT]
> **Hãy lưu mật khẩu và URL `Entrance` ngay.** Hai thông tin này chỉ hiện một lần. `Entrance` là URL đăng nhập riêng, và trình duyệt chưa đăng nhập chỉ mở được panel qua URL này. Nếu mất, xem phần [Lệnh quản trị](#lệnh-quản-trị).

> [!NOTE]
> - Panel mặc định dùng chứng chỉ HTTPS tự ký, nên trình duyệt sẽ cảnh báo ở lần truy cập đầu. Có thể tải lên chứng chỉ hợp lệ tại **Cài đặt → Chung → Chứng chỉ HTTPS của panel**.
> - Nếu máy chủ nằm trên cloud (AWS, GCP, Azure, Vultr, DigitalOcean, …), bạn cần mở thêm cổng `8888/TCP` trong Security Group hoặc firewall của nhà cung cấp.

---

## Sau khi cài đặt

1. Mở URL `Entrance` và đăng nhập bằng `admin`.
2. Lần đăng nhập đầu tiên, panel gợi ý một bộ phần mềm để cài (Nginx, MySQL, PHP, …). Bản cài mới **không cài sẵn** phần mềm nào. Tính năng **Triển khai** cần Nginx (OpenResty) và Docker.
3. Vào **Cài đặt → Chung → Bảo mật** để đổi mật khẩu và bật xác thực hai lớp.
4. Cấu hình kênh cảnh báo (**Cài đặt → Cảnh báo**) và sao lưu tự động (**Cài đặt → Sao lưu**).

Hướng dẫn chi tiết cho từng chức năng có trong [Hướng dẫn sử dụng](docs/HUONG-DAN-SU-DUNG.md).

### Phần mềm cài từ panel

Từ **Kho ứng dụng**, panel cài được Nginx (OpenResty), MySQL, MariaDB, PostgreSQL, Redis, Memcached, PHP 7.4 và 8.1–8.4, Pure-FTPd, phpMyAdmin, trình quản lý phiên bản Python và Go, …

- Đây là các **gói dựng sẵn**, tải từ `https://dl.mmoall.com`. Máy chủ không phải biên dịch gì cả.
- Trước khi cài, panel kiểm tra SHA-256 và chữ ký ed25519 của từng gói.
- Các gói cần glibc 2.31 trở lên.
- Danh sách gói hiện có nằm trong [`index.json`](https://dl.mmoall.com/index.json).

WAF (tường lửa ứng dụng web) được cung cấp dưới dạng plugin và cần Nginx/OpenResty để hoạt động.

---

## Tùy chọn cài đặt nâng cao

Để truyền tham số cho script, dùng `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash -s -- --port 9999
```

Bạn cũng có thể dùng biến môi trường. Đặt biến **sau** `sudo`:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo TSPANEL_PORT=9999 bash
```

| Tham số | Biến môi trường | Mô tả |
| --- | --- | --- |
| `--version X` | `TSPANEL_VERSION` | Cài một phiên bản cụ thể, ví dụ `0.1.0-beta.1`. Mặc định là bản mới nhất |
| `--port N` | `TSPANEL_PORT` | Cổng của panel, mặc định `8888`. Chỉ áp dụng khi cài mới |
| `--db-url URL` | `TSPANEL_DATABASE_URL` | Dùng PostgreSQL có sẵn và bỏ qua bước cài PostgreSQL |
| `--tarball PATH` | `TSPANEL_TARBALL` | Cài từ file tarball có sẵn trên máy thay vì tải về |
| `--insecure` | — | Dùng kèm `--tarball`: bỏ qua mọi bước kiểm tra. Chỉ dùng với tarball đã được kiểm tra thủ công |
| `--repo owner/name` | `TSPANEL_REPO` | Repo chứa bản phát hành, mặc định `techshield-tech/tsPanel` |
| `--no-firewall` | — | Không thay đổi `ufw`/`firewalld` |
| `--skip-db-backup` | — | Khi nâng cấp, không sao lưu database của panel trước |
| `-y` | — | Không hỏi xác nhận |
| `-h`, `--help` | — | Xem trợ giúp |

### Cài một phiên bản cụ thể

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash -s -- --version 0.1.0-beta.1
```

Danh sách các phiên bản có tại trang [Releases](https://github.com/techshield-tech/tsPanel/releases).

### Dùng PostgreSQL có sẵn

Cách này cần PostgreSQL **14 trở lên**. Trước hết, tạo user và database cho panel:

```bash
sudo -u postgres psql -c "CREATE ROLE tspanel WITH LOGIN PASSWORD 'doi-mat-khau-nay'"
sudo -u postgres psql -c "CREATE DATABASE tspanel OWNER tspanel"
```

Sau đó cài panel với `--db-url`:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh \
  | sudo bash -s -- --db-url 'postgres://tspanel:doi-mat-khau-nay@127.0.0.1:5432/tspanel?sslmode=disable'
```

### Cài từ file tải sẵn (offline)

Dùng cách này khi máy chủ không tải được từ GitHub.

1. Trên một máy khác, vào trang [Releases](https://github.com/techshield-tech/tsPanel/releases) và tải về (`<arch>` là `amd64` hoặc `arm64`):
   - `install.sh`
   - `tspanel-<version>-linux-<arch>.tar.gz`
   - `SHA256SUMS` và `SHA256SUMS.sig` (để kiểm tra chữ ký), **hoặc** `tspanel-<version>-linux-<arch>.tar.gz.sha256` (chỉ kiểm tra tính toàn vẹn)
2. Chép tất cả vào **cùng một thư mục** trên máy chủ.
3. Chạy lệnh cài:

   ```bash
   sudo bash install.sh --tarball tspanel-0.1.0-beta.1-linux-amd64.tar.gz
   ```

Máy chủ vẫn phải cài được PostgreSQL qua `apt`/`dnf`. Nếu không cài được, hãy dùng thêm `--db-url`.

---

## Nâng cấp

Bấm **Cập nhật** trên thanh trên cùng của panel, hoặc chạy lại lệnh cài đặt:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash
```

Khi thấy `/www/server/tspanel/config.yaml`, script sẽ chuyển sang chế độ **nâng cấp**:

1. Sao lưu database của panel bằng `pg_dump` (bỏ qua nếu dùng `--skip-db-backup`).
2. Dừng service và sao lưu file chạy cũ thành `tspanel.bak`.
3. Thay file chạy mới rồi khởi động lại.
4. Nếu bản mới không chạy được, script **tự quay về** file chạy cũ và khôi phục database.

Cấu hình, database và cổng được giữ nguyên. Để nâng lên một phiên bản cụ thể, thêm `--version X`. Muốn xem phiên bản đang chạy, dùng `ts version`.

---

## Lệnh quản trị

Lệnh `ts` được cài vào `/usr/local/bin/ts`. Các lệnh bên dưới cần chạy bằng `root` hoặc `sudo`.

| Lệnh | Tác dụng |
| --- | --- |
| `ts version` | Xem phiên bản panel |
| `ts reset-password admin` | Tạo mật khẩu ngẫu nhiên mới cho `admin` |
| `ts entrance show` | Xem URL đăng nhập riêng và trạng thái bật/tắt |
| `ts entrance disable` | Tắt URL đăng nhập riêng (dùng khi quên URL hoặc bị chặn) |
| `ts migrate` | Chạy migration cho database của panel |
| `ts uninstall` | Gỡ cài đặt panel |

Quản lý service:

```bash
systemctl status tspanel      # trạng thái
systemctl restart tspanel     # khởi động lại
journalctl -u tspanel -f      # xem log trực tiếp
```

---

## Vị trí file

| Đường dẫn | Nội dung |
| --- | --- |
| `/www/server/tspanel/tspanel` | File chạy của panel |
| `/www/server/tspanel/config.yaml` | Cấu hình: cổng, kết nối database, … |
| `/www/server/tspanel/data/` | Dữ liệu panel. Log nằm trong `data/logs/` (`panel.log`, `error.log`), bản sao lưu database khi nâng cấp nằm trong `data/db-backups/` |
| `/usr/local/bin/ts` | Lệnh quản trị |
| `/etc/systemd/system/tspanel.service` | Service systemd |
| `/www/server/` | Phần mềm cài từ panel |
| `/www/wwwroot/` | Mã nguồn website |
| `/www/wwwlogs/` | Log website |
| `/www/backup/` | Bản sao lưu database và thư mục |

**Đổi cổng panel:** dùng **Cài đặt → Chung → Cổng panel → Đổi cổng**. Hoặc sửa `listenAddr` trong `/www/server/tspanel/config.yaml` (ví dụ `listenAddr: ":9999"`), chạy `systemctl restart tspanel`, rồi mở cổng mới trên tường lửa.

---

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
| --- | --- |
| Không mở được panel | Kiểm tra đang dùng đúng URL `Entrance`. Kiểm tra service bằng `systemctl status tspanel` và xem cổng có đang lắng nghe không bằng `ss -ltnp \| grep 8888`. Kiểm tra cả tường lửa của nhà cung cấp cloud |
| Trình duyệt cảnh báo chứng chỉ | Panel đang dùng chứng chỉ tự ký. Tải lên chứng chỉ hợp lệ tại **Cài đặt → Chung → Chứng chỉ HTTPS của panel** |
| Quên mật khẩu | `sudo ts reset-password admin` |
| Quên URL đăng nhập riêng | Xem lại bằng `sudo ts entrance show`, hoặc tắt hẳn bằng `sudo ts entrance disable` |
| `PostgreSQL server version is too old` | Hệ điều hành có PostgreSQL cũ hơn bản 14. Cài PostgreSQL 14+ từ [postgresql.org](https://www.postgresql.org/download/) rồi cài lại với `--db-url` |
| `unsupported distribution for automatic PostgreSQL setup` | Tự cài PostgreSQL 14+ rồi cài lại với `--db-url` |
| `checksum mismatch` | File tải về bị lỗi hoặc không đầy đủ. Hãy chạy lại lệnh cài |
| Service không khởi động | Xem log bằng `journalctl -u tspanel -n 200 --no-pager` và `/www/server/tspanel/data/logs/error.log` |

Sự cố khi dùng các chức năng của panel (triển khai, tên miền, MCP, …) được mô tả trong [Hướng dẫn sử dụng](docs/HUONG-DAN-SU-DUNG.md#19-xử-lý-sự-cố).

---

## Gỡ cài đặt

> [!CAUTION]
> Thư mục `/www` chứa website, log và bản sao lưu. Hãy sao lưu những gì cần giữ trước khi xoá.

1. Gỡ các phần mềm đã cài qua panel (Nginx, MySQL, PHP, …) ngay trong **Kho ứng dụng**. Gỡ tsPanel không tự gỡ chúng.
2. Gỡ panel bằng `sudo ts uninstall`, hoặc gỡ thủ công:

   ```bash
   sudo systemctl disable --now tspanel
   sudo rm -f /etc/systemd/system/tspanel.service /usr/local/bin/ts
   sudo systemctl daemon-reload
   sudo rm -rf /www/server/tspanel
   ```

3. Nếu PostgreSQL do script cài và bạn muốn xoá database của panel:

   ```bash
   sudo -u postgres psql -c "DROP DATABASE IF EXISTS tspanel"
   sudo -u postgres psql -c "DROP ROLE IF EXISTS tspanel"
   ```

---

## Kiểm tra bản phát hành

Mỗi bản phát hành có file `SHA256SUMS`. Để tự kiểm tra các file đã tải, đặt `SHA256SUMS` cùng thư mục với chúng rồi chạy:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

---

tsPanel được phát triển bởi [**TechShield**](https://techshield.vn).
