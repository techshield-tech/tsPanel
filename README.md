# tsPanel

[![Release](https://img.shields.io/github/v/release/techshield-tech/tsPanel?include_prereleases&label=release)](https://github.com/techshield-tech/tsPanel/releases)

tsPanel là panel quản trị máy chủ Linux qua trình duyệt, do [TechShield](https://techshield.vn) phát triển. Từ một giao diện web bạn quản lý được website (Nginx/OpenResty, PHP), cơ sở dữ liệu, FTP, Docker, SSL, tác vụ định kỳ, file, terminal, giám sát tài nguyên và tường lửa ứng dụng web (WAF). Toàn bộ panel là một file chạy duy nhất.

> **Lưu ý:** tsPanel đang ở giai đoạn **beta**. Hãy chạy thử trên máy chủ mới hoặc máy thử nghiệm trước khi dùng cho môi trường production.

---

## Yêu cầu hệ thống

| Mục | Yêu cầu |
| --- | --- |
| Hệ điều hành | Ubuntu 22.04 / 24.04, Debian 12, Rocky Linux / AlmaLinux 9 |
| Kiến trúc | `x86_64` (amd64) hoặc `aarch64` (arm64) |
| Quyền | `root` hoặc tài khoản có `sudo` |
| Hệ thống init | `systemd` |
| Tài nguyên | Tối thiểu 1 vCPU, 1 GB RAM. Nếu chạy MySQL/MariaDB thì nên có từ 2 GB RAM |
| Mạng | Truy cập được `github.com` và `raw.githubusercontent.com`; mở cổng panel (mặc định `8888/TCP`) |
| Công cụ | `curl` hoặc `wget`, `tar`, `sha256sum` (hầu hết bản phân phối đã có sẵn) |

Nên cài trên **máy chủ mới**. Không cài chung với aaPanel/BT Panel hay panel khác cũng dùng thư mục `/www`.

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

Nếu đang đăng nhập bằng `root`, bạn có thể bỏ `sudo`.

Script cài đặt sẽ lần lượt:

1. Kiểm tra môi trường: quyền root, Linux, systemd và kiến trúc CPU.
2. Tải bản phát hành mới nhất từ [GitHub Releases](https://github.com/techshield-tech/tsPanel/releases) và kiểm tra SHA-256.
3. Cài PostgreSQL (qua `apt` hoặc `dnf`/`yum`), rồi tạo database và user `tspanel` với mật khẩu ngẫu nhiên.
4. Cài panel vào `/www/server/tspanel`, tạo service systemd `tspanel` và lệnh quản trị `ts`.
5. Mở cổng panel trên `ufw`/`firewalld` nếu tường lửa đang bật.
6. Tạo mật khẩu cho tài khoản `admin` và in thông tin đăng nhập.

Khi cài xong, màn hình sẽ hiện:

```text
=== tsPanel installed ===
Panel URL:    http://203.0.113.10:8888/
Username:     admin
Password:     xxxxxxxxxxxxxxxxxxxx
...
```

> **Hãy lưu mật khẩu ngay.** Mật khẩu chỉ hiện một lần. Nếu quên, chạy `sudo ts reset-password admin` để tạo mật khẩu mới.

> Nếu máy chủ nằm trên cloud (AWS, GCP, Azure, Vultr, DigitalOcean, …), bạn cần mở thêm cổng `8888/TCP` trong Security Group hoặc firewall của nhà cung cấp.

---

## Tùy chọn cài đặt

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
| `--repo owner/name` | `TSPANEL_REPO` | Repo chứa bản phát hành, mặc định `techshield-tech/tsPanel` |
| `--no-firewall` | — | Không thay đổi `ufw`/`firewalld` |
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

1. Trên một máy khác, vào trang [Releases](https://github.com/techshield-tech/tsPanel/releases) và tải ba file sau (`<arch>` là `amd64` hoặc `arm64`):
   - `install.sh`
   - `tspanel-<version>-linux-<arch>.tar.gz`
   - `tspanel-<version>-linux-<arch>.tar.gz.sha256`
2. Chép cả ba file vào **cùng một thư mục** trên máy chủ.
3. Chạy lệnh cài:

   ```bash
   sudo bash install.sh --tarball tspanel-0.1.0-beta.1-linux-amd64.tar.gz
   ```

Nếu file `.sha256` nằm cạnh tarball, script sẽ tự kiểm tra checksum. Lưu ý rằng máy chủ vẫn phải cài được PostgreSQL qua `apt`/`dnf`. Nếu không cài được, hãy dùng thêm `--db-url`.

---

## Sau khi cài đặt

1. Mở `http://<IP-máy-chủ>:8888/` và đăng nhập bằng `admin` cùng mật khẩu vừa được in ra.
2. Lần đăng nhập đầu tiên, panel sẽ gợi ý một bộ phần mềm như Nginx, MySQL, PHP. Hãy chọn những gì bạn cần rồi bấm cài. Bản cài mới **không cài sẵn** phần mềm nào.
3. Vào **Cài đặt → Bảo mật** để đổi mật khẩu, bật **xác thực 2 lớp** và đặt **URL đăng nhập riêng** (security entrance).

### Phần mềm cài từ panel

Panel cài được các phần mềm sau: Nginx (OpenResty), MySQL, MariaDB, PHP 8.2 / 8.3 / 8.4, Redis, Pure-FTPd và phpMyAdmin.

- Đây là các **gói dựng sẵn**, tải từ mục Releases (tag `packages`). Máy chủ không phải biên dịch gì cả.
- Trước khi cài, panel kiểm tra SHA-256 và chữ ký ed25519 của từng gói.
- Các gói cần glibc 2.31 trở lên.
- Danh sách gói hiện có nằm trong [`index.json`](index.json).

WAF (tường lửa ứng dụng web) có sẵn trong panel và cần Nginx/OpenResty để hoạt động.

---

## Nâng cấp

Để nâng cấp, chạy lại đúng lệnh cài đặt:

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash
```

Khi thấy `/www/server/tspanel/config.yaml`, script sẽ chuyển sang chế độ **nâng cấp**:

1. Dừng service và sao lưu file chạy cũ thành `tspanel.bak`.
2. Thay file chạy mới rồi khởi động lại.
3. Nếu bản mới không chạy được trong 60 giây, script **tự quay về** bản cũ.

Cấu hình, database và cổng được giữ nguyên. Để nâng lên một phiên bản cụ thể, thêm `--version X`.

Muốn xem phiên bản đang chạy, dùng `ts version`.

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
| `/www/server/tspanel/data/` | Dữ liệu panel; log nằm trong `data/logs/` (`panel.log`, `error.log`) |
| `/usr/local/bin/ts` | Lệnh quản trị |
| `/etc/systemd/system/tspanel.service` | Service systemd |
| `/www/server/` | Phần mềm cài từ panel |
| `/www/wwwroot/` | Mã nguồn website |
| `/www/wwwlogs/` | Log website |
| `/www/backup/` | Bản sao lưu database và thư mục |

**Đổi cổng panel:** sửa `listenAddr` trong `/www/server/tspanel/config.yaml` (ví dụ `listenAddr: ":9999"`), chạy `systemctl restart tspanel`, rồi mở cổng mới trên tường lửa.

---

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
| --- | --- |
| Không mở được panel | Kiểm tra service bằng `systemctl status tspanel` và xem cổng có đang lắng nghe không bằng `ss -ltnp \| grep 8888`. Kiểm tra cả tường lửa của nhà cung cấp cloud |
| Quên mật khẩu | `sudo ts reset-password admin` |
| Quên URL đăng nhập riêng | Xem lại bằng `sudo ts entrance show`, hoặc tắt hẳn bằng `sudo ts entrance disable` |
| `PostgreSQL server version is too old` | Hệ điều hành có PostgreSQL cũ hơn bản 14. Cài PostgreSQL 14+ từ [postgresql.org](https://www.postgresql.org/download/) rồi cài lại với `--db-url` |
| `unsupported distribution for automatic PostgreSQL setup` | Tự cài PostgreSQL 14+ rồi cài lại với `--db-url` |
| `checksum mismatch` | File tải về bị lỗi hoặc không đầy đủ. Hãy chạy lại lệnh cài |
| Service không khởi động | Xem log bằng `journalctl -u tspanel -n 200 --no-pager` và `/www/server/tspanel/data/logs/error.log` |

---

## Gỡ cài đặt

> **Cảnh báo:** Thư mục `/www` chứa website, log và bản sao lưu. Hãy sao lưu những gì cần giữ trước khi xóa.

1. Gỡ các phần mềm đã cài qua panel (Nginx, MySQL, PHP, …) ngay trong panel. Gỡ tsPanel không tự gỡ chúng.
2. Gỡ panel:

   ```bash
   sudo systemctl disable --now tspanel
   sudo rm -f /etc/systemd/system/tspanel.service /usr/local/bin/ts
   sudo systemctl daemon-reload
   sudo rm -rf /www/server/tspanel
   ```

3. Nếu PostgreSQL do script cài và bạn muốn xóa database của panel:

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
