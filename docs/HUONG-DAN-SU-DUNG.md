# Hướng dẫn sử dụng tsPanel

Tài liệu hướng dẫn cài đặt và sử dụng tsPanel. Nội dung gồm: quản lý website, triển khai ứng dụng, kết nối trợ lý AI qua MCP, cơ sở dữ liệu, tên miền và SSL, Docker, tường lửa WAF, sao lưu, giám sát và quản lý nhiều máy chủ.

- Phiên bản áp dụng: **tsPanel 0.1.0-beta.36**
- Tên menu, tab và nút bấm được viết **in đậm**, đúng như trên giao diện. Đường đi giữa các màn hình được viết dạng **Menu → Tab → Nút**.
- Giải thích thuật ngữ nằm ở [Phụ lục: Thuật ngữ](#phụ-lục-thuật-ngữ).
- Hướng dẫn cài đặt và vận hành bằng tiếng Anh: [Installation Guide](INSTALL.md).

---

## Mục lục

1. [Giới thiệu](#1-giới-thiệu)
2. [Cài đặt](#2-cài-đặt)
3. [Giao diện](#3-giao-diện)
4. [Thiết lập ban đầu](#4-thiết-lập-ban-đầu)
5. [Triển khai ứng dụng](#5-triển-khai-ứng-dụng)
6. [AI / MCP](#6-ai--mcp)
7. [Cơ sở dữ liệu](#7-cơ-sở-dữ-liệu)
8. [Tên miền và chứng chỉ SSL](#8-tên-miền-và-chứng-chỉ-ssl)
9. [Website](#9-website)
10. [Tệp tin, Terminal và FTP](#10-tệp-tin-terminal-và-ftp)
11. [Tác vụ định kỳ](#11-tác-vụ-định-kỳ)
12. [Giám sát](#12-giám-sát)
13. [Nhật ký](#13-nhật-ký)
14. [WAF](#14-waf)
15. [Docker](#15-docker)
16. [Node](#16-node)
17. [Kho ứng dụng](#17-kho-ứng-dụng)
18. [Cài đặt panel](#18-cài-đặt-panel)
19. [Xử lý sự cố](#19-xử-lý-sự-cố)
20. [Nâng cấp](#20-nâng-cấp)
21. [Gỡ cài đặt](#21-gỡ-cài-đặt)

[Phụ lục: Thuật ngữ](#phụ-lục-thuật-ngữ)

---

## 1. Giới thiệu

tsPanel là panel quản trị máy chủ Linux qua trình duyệt. Mọi chức năng đều nằm trong một giao diện web, gồm:

| Nhóm chức năng | Mô tả |
| --- | --- |
| Triển khai ứng dụng | Build và chạy ứng dụng trong container, lấy mã nguồn từ Git, tệp zip, thư mục trên máy chủ hoặc Docker image. Hỗ trợ gắn tên miền, cấp HTTPS, khai báo biến môi trường, xem lịch sử triển khai và rollback. |
| AI / MCP | Cho phép trợ lý AI (Claude Code, Claude Desktop, Cursor, VS Code, Windsurf, Codex CLI, Gemini CLI) tạo, triển khai và theo dõi dự án thông qua Model Context Protocol. |
| Website | Quản lý website PHP hoặc web tĩnh, và các dự án Node.js, Python, Go, Proxy chạy sau Nginx (OpenResty). |
| Cơ sở dữ liệu | Quản lý MySQL/MariaDB, PostgreSQL, MongoDB, Redis, SQL Server, cả trên máy chủ này lẫn máy chủ từ xa. |
| Tên miền | Kết nối nhà cung cấp DNS, quản lý bản ghi, cấp và tự gia hạn chứng chỉ Let's Encrypt. |
| Docker | Quản lý container, image, Compose, mạng, volume, registry và cấu hình Docker daemon. |
| Bảo mật | Tường lửa ứng dụng web (Coraza + OWASP CRS), URL đăng nhập riêng, xác thực hai lớp, nhật ký kiểm toán. |
| Vận hành | Giám sát tài nguyên, nhật ký, tác vụ định kỳ, sao lưu, cảnh báo, trình quản lý tệp, terminal web. |
| Nhiều máy chủ | Quản lý thêm máy chủ khác thông qua agent, tất cả từ một panel chính (master). |

---

## 2. Cài đặt

### 2.1 Yêu cầu hệ thống

| Mục | Yêu cầu |
| --- | --- |
| Hệ điều hành | Ubuntu 22.04 / 24.04, Debian 12, Rocky Linux 9, AlmaLinux 9 |
| Kiến trúc | `x86_64` (amd64) hoặc `aarch64` (arm64) |
| Tài nguyên | Tối thiểu 1 vCPU và 1 GB RAM. Nếu chạy cơ sở dữ liệu hoặc nhiều ứng dụng, nên có từ 2 GB RAM |
| Quyền | `root` hoặc tài khoản có `sudo` |
| Hệ thống init | `systemd` |
| Mạng | Truy cập được `github.com` và `raw.githubusercontent.com`. Cổng panel mặc định là `8888/TCP` |
| Công cụ | `curl` hoặc `wget`, `tar`, `sha256sum` (hầu hết bản phân phối đã có sẵn) |

> [!WARNING]
> Nên cài trên máy chủ mới. Không cài chung với aaPanel, BT Panel hoặc panel khác cũng dùng thư mục `/www`.

Panel lưu dữ liệu trong **PostgreSQL 14 trở lên**, và script cài đặt sẽ tự cài PostgreSQL. Ubuntu 20.04 và Debian 11 chỉ có PostgreSQL cũ hơn bản 14 nên script sẽ dừng lại. Với các hệ điều hành này, hãy [dùng PostgreSQL có sẵn](#dùng-postgresql-có-sẵn).

### 2.2 Cài đặt

Kết nối SSH tới máy chủ bằng tài khoản `root`:

```bash
ssh root@203.0.113.10
```

Chạy lệnh cài đặt:

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
2. Tải bản phát hành mới nhất từ [GitHub Releases](https://github.com/techshield-tech/tsPanel/releases), kiểm tra chữ ký và tính toàn vẹn.
3. Cài PostgreSQL (qua `apt` hoặc `dnf`/`yum`), rồi tạo database và user `tspanel` với mật khẩu ngẫu nhiên.
4. Cài panel vào `/www/server/tspanel`, tạo service systemd `tspanel` và lệnh quản trị `ts`.
5. Nếu `ufw`/`firewalld` đang bật, mở cổng panel và cổng `8889/TCP` (cổng của agent node).
6. Tạo mật khẩu cho tài khoản `admin` và in ra thông tin đăng nhập.

Khi hoàn tất, script in ra thông tin đăng nhập:

```text
=== tsPanel installed ===
Panel URL:    https://203.0.113.10:8888/
Username:     admin
Password:     xxxxxxxxxxxxxxxxxxxx
Entrance:     https://203.0.113.10:8888/xxxxxxxx   (the only URL that opens the panel; save it)
```

| Dòng | Ý nghĩa |
| --- | --- |
| `Panel URL` | Địa chỉ của panel |
| `Username` / `Password` | Tài khoản quản trị. Mật khẩu chỉ được in ra **một lần** |
| `Entrance` | URL đăng nhập riêng. Trình duyệt chưa đăng nhập chỉ mở được panel qua URL này |

> [!IMPORTANT]
> Hãy lưu mật khẩu và URL `Entrance` ngay. Nếu bị mất, có thể khôi phục bằng lệnh `ts`, xem [mục 19.2](#192-lệnh-quản-trị).

Các tuỳ chọn cài đặt nâng cao (đổi cổng, cài phiên bản cụ thể, dùng PostgreSQL có sẵn, cài offline) được mô tả ở [mục 2.5](#25-tuỳ-chọn-cài-đặt-nâng-cao).

### 2.3 Truy cập lần đầu

1. Mở URL `Entrance`. Nếu kết quả cài đặt không có dòng `Entrance`, mở `Panel URL`.
2. Mặc định, panel dùng chứng chỉ HTTPS tự ký, nên trình duyệt sẽ hiện cảnh báo kết nối không riêng tư. Chọn **Nâng cao → Tiếp tục** để vào panel. Để bỏ cảnh báo này, hãy dùng chứng chỉ hợp lệ cho panel, xem [mục 18.2](#182-chứng-chỉ-https-của-panel).
3. Đăng nhập bằng tài khoản `admin`.

> [!NOTE]
> Nếu máy chủ nằm trên cloud (AWS, Google Cloud, Azure, Vultr, DigitalOcean, …), cần mở cổng `8888/TCP` trong Security Group hoặc firewall của nhà cung cấp.

### 2.4 Chọn phần mềm

Bản cài mới chưa có phần mềm nào. Ở lần đăng nhập đầu tiên, panel gợi ý một bộ phần mềm để cài. Bạn cũng có thể cài bất kỳ lúc nào trong [Kho ứng dụng](#17-kho-ứng-dụng).

| Mục đích sử dụng | Phần mềm cần có |
| --- | --- |
| Triển khai ứng dụng bằng **Triển khai** | Nginx (OpenResty), Docker |
| Website PHP / WordPress | Nginx (OpenResty), PHP 8.x, MySQL hoặc MariaDB |
| Cơ sở dữ liệu | PostgreSQL, MySQL/MariaDB, MongoDB, Redis hoặc SQL Server, tuỳ ứng dụng |
| Tường lửa WAF | Nginx (OpenResty) |

### 2.5 Tuỳ chọn cài đặt nâng cao

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

#### Cài một phiên bản cụ thể

```bash
curl -fsSL https://raw.githubusercontent.com/techshield-tech/tsPanel/main/install.sh | sudo bash -s -- --version 0.1.0-beta.1
```

Danh sách các phiên bản có tại trang [Releases](https://github.com/techshield-tech/tsPanel/releases).

#### Dùng PostgreSQL có sẵn

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

#### Cài từ file tải sẵn (offline)

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

#### Kiểm tra bản phát hành

Mỗi bản phát hành có file `SHA256SUMS`. Để tự kiểm tra các file đã tải, đặt `SHA256SUMS` cùng thư mục với chúng rồi chạy:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

Script cài đặt cũng tự kiểm tra chữ ký ed25519 trong `SHA256SUMS.sig`.

---

## 3. Giao diện

![Trang chủ](images/01-home.png)

### 3.1 Thanh bên

| Menu | Chức năng |
| --- | --- |
| **Trang chủ** | Tổng quan tình trạng máy chủ |
| **Website** | Dự án PHP, Node.js, Proxy, Go, Python |
| **FTP** | Tài khoản FTP |
| **Cơ sở dữ liệu** | MySQL, SQL Server, MongoDB, Redis, PostgreSQL |
| **Docker** | Container, image, Compose, mạng, volume, registry |
| **Triển khai** | Dự án triển khai, thông tin đăng nhập Git, AI / MCP |
| **Giám sát** | Lịch sử CPU, bộ nhớ, tải hệ thống, IO đĩa, mạng |
| **WAF** | Tường lửa ứng dụng web |
| **Tệp tin** | Trình quản lý tệp và trình soạn thảo |
| **Node** | Quản lý nhiều máy chủ |
| **Nhật ký** | Nhật ký panel, website, hệ thống, SSH, phần mềm |
| **Tên miền** | DNS và chứng chỉ SSL |
| **Terminal** | Terminal web |
| **Tác vụ định kỳ** | Tác vụ, luồng tác vụ, thư viện script |
| **Kho ứng dụng** | Cài, cấu hình và gỡ phần mềm |
| **Cài đặt** | Cài đặt chung, giao diện, cảnh báo, sao lưu, dịch vụ panel, plugin |

Phía trên thanh bên:

- Biểu tượng **chuông** (kèm số chưa đọc) mở trung tâm thông báo.
- Biểu tượng **danh sách** mở hàng đợi tác vụ.
- Ô **Master** dùng để chọn máy chủ đang quản lý, xem [Node](#16-node).

Phía dưới thanh bên có các nút: thu gọn thanh bên, chuyển giao diện sáng/tối, đổi ngôn ngữ.

Thanh trên cùng hiển thị tài khoản, tên máy chủ, phiên bản panel, nút **Cập nhật** và nút **Khởi động lại** panel.

### 3.2 Thông báo và hàng đợi tác vụ

| Thông báo | Hàng đợi tác vụ |
| --- | --- |
| ![Thông báo](images/02-home-notifications.png) | ![Hàng đợi tác vụ](images/03-home-task-queue.png) |

- **Thông báo:** ghi lại sự kiện của panel, như tác vụ hoàn tất hoặc thất bại, node trực tuyến hoặc ngoại tuyến, cấp chứng chỉ, triển khai. Có nút xoá toàn bộ thông báo.
- **Hàng đợi tác vụ:** theo dõi các tác vụ chạy nền như cài phần mềm, sao lưu, cập nhật.

### 3.3 Trang chủ

| Khu vực | Nội dung |
| --- | --- |
| Hàng chỉ số | Tải hệ thống (1/5/15 phút), CPU, RAM, dung lượng từng phân vùng đĩa |
| **Tổng quan** | Số website (đang chạy / đã dừng), tài khoản FTP, cơ sở dữ liệu, rủi ro bảo mật và thời điểm quét gần nhất, ghi chú |
| **Phần mềm** | Phần mềm được ghim ra trang chủ. **Thêm** để ghim thêm |
| **Lưu lượng** | Tốc độ gửi/nhận, tổng dữ liệu đã gửi/nhận, đọc/ghi đĩa theo thời gian thực |

---

## 4. Thiết lập ban đầu

Các thiết lập nên làm ngay sau khi cài đặt:

| # | Thiết lập | Vị trí |
| --- | --- | --- |
| 1 | Đổi mật khẩu quản trị | **Cài đặt → Chung → Bảo mật → Mật khẩu** |
| 2 | Lưu URL đăng nhập | **Cài đặt → Chung → Bảo mật → URL đăng nhập** |
| 3 | Bật xác thực hai lớp | **Cài đặt → Chung → Bảo mật → Xác thực hai lớp** |
| 4 | Đặt múi giờ | **Cài đặt → Chung → Panel → Múi giờ** |
| 5 | Cấu hình kênh cảnh báo | **Cài đặt → Cảnh báo** |
| 6 | Bật sao lưu tự động | **Cài đặt → Sao lưu** |

### 4.1 Mật khẩu, URL đăng nhập, xác thực hai lớp

![Cài đặt chung](images/77-settings-general.png)

- **Mật khẩu → Đổi mật khẩu:** cần nhập mật khẩu hiện tại, mật khẩu mới và nhập lại. Có nút tạo mật khẩu ngẫu nhiên.

  ![Đổi mật khẩu](images/83-change-password.png)

- **URL đăng nhập:** URL duy nhất mà trình duyệt chưa đăng nhập dùng được để vào panel. Trên màn hình, URL được che dưới dạng `/••••••••`. Dùng nút sao chép để lấy URL, hoặc **Đổi** để đặt URL mới.
- **Xác thực hai lớp:** bật để yêu cầu nhập mã từ ứng dụng xác thực (Google Authenticator, Microsoft Authenticator, Authy, …) mỗi lần đăng nhập.
- **Xác thực HTTP cơ bản:** thêm một lớp đăng nhập trước trang đăng nhập của panel.
- **Cảnh báo đăng nhập:** gửi thông báo mỗi khi có người đăng nhập panel. Cần cấu hình kênh cảnh báo trước.
- **Hết hạn mật khẩu:** buộc đổi mật khẩu sau số ngày đã đặt. Nhập `0` để tắt.

### 4.2 Cảnh báo

![Cảnh báo](images/79-settings-alerts.png)

1. Chọn kênh **Email** (SMTP), **Telegram** hoặc **Webhook**, rồi bấm **Thiết lập** và nhập thông tin.
2. Bấm **Gửi thử** để kiểm tra kênh đã hoạt động.
3. Bấm **Thêm quy tắc** để khai báo sự kiện nào thì gửi cảnh báo.
4. Các cảnh báo đã gửi được ghi lại trong **Nhật ký cảnh báo**.

### 4.3 Sao lưu

![Sao lưu](images/80-settings-backup.png)

- **Sao lưu tự động:** bật **Bật sao lưu tự động**, chọn **Thời gian** chạy, số ngày **Giữ trong** và **Thư mục sao lưu**, rồi bấm **Lưu**.
- **Sao lưu ngay:** tạo ngay một bản sao lưu thủ công, gồm website, cơ sở dữ liệu và cài đặt panel.

> [!WARNING]
> Bản sao lưu được lưu trên chính máy chủ đó. Nên định kỳ tải bản sao lưu về nơi khác, hoặc dùng thêm tính năng snapshot của nhà cung cấp máy chủ.

---

## 5. Triển khai ứng dụng

**Triển khai** build ứng dụng thành Docker image, chạy nó trong container, kiểm tra sức khoẻ, rồi định tuyến tên miền tới container. Menu này có ba tab: **Dự án**, **Thông tin đăng nhập Git** và **AI / MCP**.

![Danh sách dự án](images/27-deploy-projects.png)

Mỗi thẻ dự án hiển thị: tên, ghi chú, trạng thái container, tên miền, nguồn mã, chế độ build, kết quả và số hiệu lần triển khai gần nhất (`r1`, `r2`, …), cùng thời gian triển khai. Có thể chuyển giữa dạng lưới và dạng danh sách, hoặc tìm theo tên và repository.

### 5.1 Quy trình triển khai

Mỗi lần triển khai đi qua 4 bước:

1. **Lấy mã nguồn** từ nguồn đã chọn.
2. **Build image** theo Dockerfile hoặc tệp compose.
3. **Kiểm tra sức khoẻ:** gửi yêu cầu HTTP tới container cho đến khi ứng dụng phản hồi, hoặc cho đến khi hết thời gian chờ.
4. **Định tuyến tên miền:** tạo reverse proxy từ tên miền tới cổng của container.

### 5.2 Yêu cầu đối với mã nguồn

| Yêu cầu | Chi tiết |
| --- | --- |
| Tệp build | Có `Dockerfile` hoặc tệp compose (`compose.yaml`). Nếu không nằm ở thư mục gốc, hãy khai báo **Thư mục con** trong cài đặt dự án |
| Địa chỉ lắng nghe | Ứng dụng phải lắng nghe trên `0.0.0.0`, không phải `127.0.0.1` hay `localhost` |
| Cổng | Biết rõ cổng ứng dụng lắng nghe bên trong container, ví dụ `3000`, `8000`, `80` |
| Health check | Có một đường dẫn trả về mã `200`. Mặc định là `/` |
| Bí mật | Không đưa tệp `.env` chứa thông tin bí mật vào mã nguồn. Khai báo các giá trị này trong tab **Biến môi trường** |
| `.dockerignore` | Nên loại trừ `node_modules`, `.git`, `.env` và các tệp build tạm |

### 5.3 Tạo dự án

Vào **Triển khai → Dự án → Dự án mới**. Wizard có 3 bước: **Nguồn → Chi tiết → Cài đặt**.

![Tạo dự án mới](images/28-deploy-new-project.png)

**Bước 1. Nguồn**

| Nguồn | Mô tả |
| --- | --- |
| **Repository Git** | Clone từ GitHub hoặc máy chủ Git bất kỳ, và tự triển khai lại khi có push. Repository riêng tư cần [thông tin đăng nhập Git](#59-thông-tin-đăng-nhập-git) |
| **Tải lên tệp zip** | Tải lên tệp nén chứa mã nguồn dự án |
| **Thư mục trên máy chủ** | Build từ một thư mục đã có sẵn trên máy chủ |
| **Docker image** | Chạy một image có sẵn từ registry |

**Bước 2. Chi tiết:** thông tin của nguồn, ví dụ URL repository và nhánh, tệp zip, đường dẫn thư mục hoặc tên image.

**Bước 3. Cài đặt:** tên dự án, mạng và biến môi trường.

| Trường | Mô tả |
| --- | --- |
| Tên | Định danh của dự án, **không đổi được sau khi tạo**. Nên dùng chữ thường không dấu, số và dấu gạch ngang |
| Cổng container | Cổng ứng dụng lắng nghe bên trong container |
| Cổng công bố | Cổng trên máy chủ được nối tới cổng container |
| Tên miền | Có thể khai báo ngay, hoặc thêm sau trong tab **Tên miền** |
| Biến môi trường | Có thể khai báo ngay, hoặc thêm sau trong tab **Biến môi trường** |

Khung **Tóm tắt** bên phải hiển thị cấu hình đang nhập. Khung **Điều gì xảy ra tiếp theo** liệt kê các bước sẽ chạy sau khi tạo dự án.

### 5.4 Chi tiết dự án

![Chi tiết dự án – Tổng quan](images/29-deploy-project-overview.png)

**Các nút ở đầu trang:**

| Nút | Chức năng |
| --- | --- |
| **Truy cập** | Mở ứng dụng trong tab mới |
| **Tải lên tệp zip mới** | Thay mã nguồn bằng tệp zip mới (với dự án có nguồn tải lên) |
| ▷ / ⟳ / ■ | Chạy / Khởi động lại / Dừng container |
| **Triển khai lại** | Build và triển khai lại dự án |

Các nhãn dưới tên dự án cho biết chế độ build, ánh xạ cổng (ví dụ `25025 → 80` là cổng 25025 trên máy chủ nối tới cổng 80 trong container) và thời điểm triển khai gần nhất.

**Tab Tổng quan:**

- **Bản triển khai production:** phiên bản đang phục vụ truy cập. Nút **Nhật ký build** mở log build của phiên bản này.
- **Tài nguyên container:** CPU, bộ nhớ, lưu lượng mạng và số tiến trình.
- **Khung Dự án:** URL, tên miền, nguồn, chế độ build, số container đang chạy, cổng cục bộ, chính sách khởi động lại, cấu hình health check và ngày tạo. Chính sách `unless-stopped` nghĩa là container tự khởi động lại khi máy chủ khởi động, trừ khi đã bị dừng thủ công.

### 5.5 Tên miền và HTTPS

![Chi tiết dự án – Tên miền](images/31-deploy-project-domains.png)

1. Trong tab **Tên miền**, nhập tên miền (ví dụ `app.example.com`), bấm **Thêm**, rồi bấm **Lưu tên miền**.
2. Trỏ tên miền về máy chủ theo một trong hai cách:
   - **Tự động:** chọn một [nhà cung cấp DNS đã kết nối](#81-nhà-cung-cấp-dns) ở ô **Nhà cung cấp DNS**. Bản ghi A sẽ được tạo tự động cho mọi tên miền của dự án.
   - **Thủ công:** tạo bản ghi A tại nhà cung cấp DNS, dùng tên miền và **Giá trị** (IP máy chủ) hiển thị trong khung **DNS**.
3. Trong khung **Chứng chỉ HTTPS**:
   - **Bật HTTPS (Let's Encrypt):** yêu cầu chứng chỉ miễn phí. Tên miền phải trỏ về máy chủ trước khi bật.
   - **Chuyển hướng HTTP sang HTTPS:** chuyển hướng `http://` sang `https://` bằng mã 301. Việc gia hạn chứng chỉ vẫn hoạt động qua HTTP.

> [!NOTE]
> Mỗi tên miền của dự án tạo ra một mục trong **Website → Dự án Proxy**, có ghi chú `deploy:<tên-dự-án>`. Hãy quản lý các mục này từ trang dự án, không sửa hay xoá trực tiếp trong menu Website.
>
> ![Proxy của dự án triển khai](images/07-website-proxy.png)

### 5.6 Biến môi trường

![Chi tiết dự án – Biến môi trường](images/32-deploy-project-env.png)

- **Thêm biến:** thêm từng cặp **Khoá** / **Giá trị**.
- **Nhập .env:** dán nội dung tệp `.env` để thêm nhiều biến cùng lúc.
- Biến môi trường được lưu mã hoá. Biến được truyền vào container, hoặc ghi vào tệp `.env` khi dự án dùng compose.

> [!IMPORTANT]
> Thay đổi biến môi trường chỉ có hiệu lực sau khi **Triển khai lại**.

### 5.7 Cập nhật phiên bản

| Nguồn | Cách cập nhật |
| --- | --- |
| Tệp zip | **Tải lên tệp zip mới** ở đầu trang dự án |
| Repository Git | Push lên repository (dự án tự triển khai lại), hoặc bấm **Triển khai lại** |
| Mọi nguồn | **Triển khai lại** sau khi đổi biến môi trường hoặc cài đặt |

Mỗi lần triển khai được đánh số tăng dần: `r1`, `r2`, `r3`, …

### 5.8 Lịch sử triển khai và nhật ký

**Tab Triển khai** liệt kê các lần triển khai cùng trạng thái, cách kích hoạt (thủ công hoặc tự động), thời điểm và thời lượng. Lần đang phục vụ được gắn nhãn **Đang phục vụ**. Khung bên phải hiển thị log build và log health check của lần đang chọn, có tuỳ chọn **Tự cuộn** và tải log về.

![Chi tiết dự án – Triển khai](images/30-deploy-project-deployments.png)

> [!NOTE]
> Các dòng `Health check #N ... connection reset by peer` hoặc `connection refused` xuất hiện ngay sau khi container khởi động là bình thường. Health check sẽ thử lại cho tới khi ứng dụng phản hồi hoặc hết thời gian chờ (mặc định 60 giây).

**Tab Nhật ký** hiển thị stdout/stderr của container đang chạy. Có thể chọn số dòng gần nhất cần xem, bật **Tự làm mới**, **Tự cuộn**, hoặc tải log về.

![Chi tiết dự án – Nhật ký](images/33-deploy-project-logs.png)

> [!NOTE]
> Các yêu cầu tới những đường dẫn như `/vendor/phpunit/...`, `/index.php?s=/index/think...` hay `/containers/json` và nhận mã `404` thường đến từ công cụ dò lỗ hổng tự động trên Internet. Có thể dùng [WAF](#14-waf) để chặn bớt.

**Rollback:** lịch sử ở tab Triển khai lưu lại các phiên bản trước. Việc rollback về một lần triển khai thành công cũng có thể thực hiện qua [AI / MCP](#6-ai--mcp) bằng công cụ `rollback`.

### 5.9 Thông tin đăng nhập Git

Vào **Triển khai → Thông tin đăng nhập Git → Thêm thông tin đăng nhập** để lưu access token hoặc SSH key dùng cho việc clone repository riêng tư.

![Thông tin đăng nhập Git](images/35-deploy-git-credentials.png)

Với GitHub, tạo token tại **Settings → Developer settings → Personal access tokens**. Nên dùng *fine-grained token*, chỉ cấp quyền **Contents: Read-only** cho những repository cần triển khai.

### 5.10 Cài đặt dự án

![Chi tiết dự án – Cài đặt](images/34-deploy-project-settings.png)

| Nhóm | Trường |
| --- | --- |
| **Chung** | Tên (không đổi được), Ghi chú |
| **Nguồn** | **Thư mục con** (build context bên trong mã nguồn; để trống nếu dùng thư mục gốc), **File compose**, **Dockerfile** (để trống thì tự phát hiện) |
| **Chạy** | **Cổng container**, **Đường dẫn kiểm tra sức khoẻ**, **Thời gian chờ kiểm tra (giây)** |
| **Cổng bổ sung** | Các cổng khác cần công bố |
| **Vùng nguy hiểm** | Xoá dự án |

### 5.11 Lỗi triển khai thường gặp

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
| --- | --- | --- |
| Build báo không tìm thấy Dockerfile | Dockerfile không nằm ở thư mục gốc | Khai báo **Thư mục con** hoặc **Dockerfile** trong tab Cài đặt |
| Lỗi khi cài thư viện (`npm ERR!`, `pip ... error`, …) | Thiếu tệp lock, sai phiên bản runtime trong Dockerfile | Sửa Dockerfile hoặc tệp phụ thuộc, rồi triển khai lại |
| Health check lỗi `connection refused` / `connection reset` cho tới khi hết thời gian chờ | Sai cổng container, ứng dụng chỉ lắng nghe trên `localhost`, hoặc ứng dụng khởi động chậm | Sửa **Cổng container**, cho ứng dụng lắng nghe trên `0.0.0.0`, tăng **Thời gian chờ kiểm tra** |
| Health check trả về `404` hoặc `500` | Đường dẫn health check không tồn tại hoặc đang lỗi | Đổi **Đường dẫn kiểm tra sức khoẻ** |
| Container dừng ngay sau khi chạy | Thiếu biến môi trường, không kết nối được cơ sở dữ liệu | Xem tab **Nhật ký**, bổ sung biến, rồi triển khai lại |
| Tên miền trả về `502 Bad Gateway` | Container đã dừng hoặc sai cổng | Xem tab **Nhật ký**, khởi động lại container, kiểm tra cổng |
| Không cấp được HTTPS | Tên miền chưa trỏ về máy chủ, hoặc cổng 80/443 bị chặn | Kiểm tra bản ghi A, mở cổng 80 và 443 trên firewall của nhà cung cấp |

### 5.12 Dữ liệu của ứng dụng

Mỗi lần triển khai lại sẽ tạo container mới. Dữ liệu ghi bên trong container (tệp tải lên, cơ sở dữ liệu SQLite, …) không được giữ lại giữa các lần triển khai. Hãy lưu dữ liệu cần giữ lâu dài vào [cơ sở dữ liệu](#7-cơ-sở-dữ-liệu), volume, hoặc dịch vụ lưu trữ bên ngoài.

---

## 6. AI / MCP

**Triển khai → AI / MCP** bật máy chủ MCP (Model Context Protocol). Khi bật, các client AI có thể tạo, triển khai, theo dõi và rollback dự án bằng ngôn ngữ tự nhiên. Mỗi client xác thực bằng một khoá API riêng, và phạm vi quyền do khoá đó quyết định.

Trang có 6 tab: **Tổng quan**, **Khoá API**, **Kết nối client**, **Công cụ**, **Quy trình & prompt mẫu**, **Bảo mật & xử lý sự cố**.

### 6.1 Bật máy chủ MCP

![AI / MCP – Tổng quan](images/36-deploy-mcp-overview.png)

Bật công tắc **Máy chủ MCP** rồi sao chép **URL endpoint**, có dạng `https://<IP>:8888/api/v1/mcp`. Tab này cũng hiển thị tên máy chủ, phiên bản máy chủ, phiên bản giao thức và số khoá API.

> [!WARNING]
> URL đăng nhập riêng, danh sách IP được phép của panel và Basic Auth **chỉ bảo vệ giao diện web**. Endpoint MCP chỉ được bảo vệ bằng khoá API.

### 6.2 Khoá API

![AI / MCP – Khoá API](images/37-deploy-mcp-keys.png)

Bấm **Tạo khoá API** và khai báo:

| Trường | Mô tả |
| --- | --- |
| Tên | Tên nhận diện, ví dụ theo máy hoặc theo client |
| Quyền | **Chỉ đọc**: xem trạng thái dự án, lịch sử triển khai và log.<br>**Triển khai**: tạo và cập nhật dự án, tải tệp lên, triển khai, rollback, khởi động/dừng, biến môi trường, tên miền, bản xem trước. Không có quyền xoá.<br>**Toàn quyền**: có thêm quyền xoá |
| Dự án | Tất cả dự án, hoặc chỉ các dự án được chọn |
| IP được phép | Giới hạn những địa chỉ IP được dùng khoá |
| Hết hạn | Thời điểm khoá hết hiệu lực |

> [!IMPORTANT]
> Khoá đầy đủ (dạng `tsp_mcp_...`) chỉ hiển thị **một lần** khi tạo. Bảng danh sách chỉ hiển thị tiền tố của khoá, cùng thời điểm và IP của lần dùng gần nhất.

### 6.3 Kết nối client

![AI / MCP – Kết nối client](images/38-deploy-mcp-clients.png)

Chọn tab tương ứng với client đang dùng: **Claude Code**, **Claude Desktop**, **Cursor**, **VS Code**, **Windsurf**, **Codex CLI**, **Gemini CLI**, hoặc **Thử bằng curl**. Mỗi tab có sẵn lệnh và cấu hình mẫu, kèm nút sao chép.

Ví dụ với Claude Code:

```bash
claude mcp add --transport http tspanel https://203.0.113.10:8888/api/v1/mcp --header "Authorization: Bearer <YOUR_MCP_KEY>"
```

Hoặc dùng tệp `.mcp.json` theo dự án, đọc khoá từ biến môi trường `TSPANEL_MCP_KEY`:

```json
{
  "mcpServers": {
    "tspanel": {
      "type": "http",
      "url": "https://203.0.113.10:8888/api/v1/mcp",
      "headers": {
        "Authorization": "Bearer ${TSPANEL_MCP_KEY}"
      }
    }
  }
}
```

> [!NOTE]
> Khi panel dùng chứng chỉ tự ký, các client chạy trên Node.js cần tin cậy CA của chứng chỉ đó, ví dụ bằng `NODE_EXTRA_CA_CERTS=/path/to/ca.pem`. Cách khác là dùng chứng chỉ hợp lệ cho panel, xem [mục 18.2](#182-chứng-chỉ-https-của-panel).

### 6.4 Công cụ

![AI / MCP – Công cụ](images/39-deploy-mcp-tools.png)

Máy chủ MCP cung cấp 25 công cụ, được gắn nhãn **Chỉ đọc** hoặc **Triển khai**. Mỗi khoá chỉ gọi được những công cụ nằm trong phạm vi quyền của nó. Một số công cụ chính:

| Công cụ | Chức năng |
| --- | --- |
| `get_server_info` | Thông tin máy chủ và khoá |
| `list_projects`, `get_project` | Danh sách và chi tiết dự án |
| `list_deployments`, `get_deployment_log`, `wait_for_deployment` | Lịch sử triển khai, log build, chờ triển khai hoàn tất |
| `get_container_logs`, `get_project_stats` | Log và tài nguyên của container |
| `detect_build` | Phát hiện chế độ build và cổng của repository |
| `create_project`, `upload_files`, `create_upload_url`, `deploy` | Tạo dự án, tải mã nguồn lên, triển khai |
| `set_domains`, `list_dns_providers` | Gắn tên miền, SSL, nhà cung cấp DNS |
| `rollback`, `project_action` | Rollback; chạy, dừng, khởi động lại container |
| `create_preview`, `list_previews`, `delete_preview` | Bản xem trước theo nhánh Git |

### 6.5 Quy trình và prompt mẫu

![AI / MCP – Quy trình](images/40-deploy-mcp-workflows.png)

Client AI tự chọn công cụ dựa trên mục tiêu được mô tả. Các quy trình thường dùng:

| Quy trình | Các bước |
| --- | --- |
| Triển khai thư mục cục bộ | `create_project` (source_type `upload`) → `upload_files` hoặc `create_upload_url` → `deploy` → `wait_for_deployment` → khi lỗi thì `get_deployment_log` |
| Triển khai kho Git | `list_git_credentials` → `detect_build` → `create_project` → `deploy` → `wait_for_deployment` |
| Tên miền riêng với SSL | Trỏ bản ghi A, hoặc chọn nhà cung cấp từ `list_dns_providers` → `set_domains` có `ssl` → kiểm tra HTTPS |
| Rollback hoặc khởi động lại | `list_deployments` → `rollback` → `wait_for_deployment`; hoặc `project_action` và `get_container_logs` |
| Xem trước một nhánh | `create_preview` → `wait_for_deployment` → `list_previews` → `delete_preview` (cần toàn quyền) |

Ví dụ yêu cầu gửi cho client AI:

```text
Triển khai thư mục hiện tại lên tsPanel thành dự án "shop", cổng container 3000.
Nếu build lỗi, đọc log build, sửa và triển khai lại.
```

```text
Gắn tên miền shop.example.com cho dự án "shop", bật HTTPS và chuyển hướng HTTP sang HTTPS.
```

```text
Rollback dự án "shop" về lần triển khai thành công gần nhất.
```

### 6.6 Bảo mật và mã lỗi

![AI / MCP – Bảo mật & xử lý sự cố](images/41-deploy-mcp-security.png)

Khuyến nghị:

- **Quyền tối thiểu:** dùng **Chỉ đọc** để giám sát, **Triển khai** cho công việc hằng ngày, và **Toàn quyền** chỉ khi cần xoá.
- **Mỗi dự án hoặc mỗi máy một khoá:** giới hạn phạm vi ảnh hưởng khi một khoá bị lộ.
- **Giới hạn theo IP:** chỉ cho phép IP văn phòng, CI hoặc VPN.
- **Đặt thời hạn:** 7, 30 hoặc 90 ngày, và thay khoá định kỳ.
- **Thu hồi ngay khi bị lộ:** khi khoá xuất hiện trong mã nguồn, nhật ký chat hoặc ảnh chụp màn hình.
- **Không commit khoá:** lưu khoá trong biến môi trường `TSPANEL_MCP_KEY`.

| Mã | Nguyên nhân | Cách khắc phục |
| --- | --- | --- |
| `401` | Khoá sai, hết hạn hoặc đã bị thu hồi; hoặc IP không nằm trong danh sách được phép | Kiểm tra header `Authorization: Bearer`, thời hạn và IP được phép, hoặc tạo khoá mới |
| `404` | Máy chủ MCP đang tắt hoặc URL không đúng | Bật MCP ở tab Tổng quan, kiểm tra URL endpoint |
| `405` | Client mở luồng GET hoặc SSE | Cấu hình client dùng transport HTTP (streamable HTTP) |
| `429` | Quá nhiều yêu cầu trong thời gian ngắn | Chờ rồi thử lại |
| Lỗi tải lên | URL tải lên đã hết hạn, tệp quá lớn so với `upload_files`, hoặc khoá không có quyền với dự án | Xin URL mới bằng `create_upload_url`, kiểm tra quyền dự án của khoá |

---

## 7. Cơ sở dữ liệu

Menu **Cơ sở dữ liệu** có các tab **MySQL**, **SQL Server**, **MongoDB**, **Redis** và **PostgreSQL**. Nếu một loại cơ sở dữ liệu chưa được cài, tab đó sẽ hiện nút cài đặt tương ứng. Các tab MySQL, SQL Server, MongoDB và PostgreSQL có thêm mục quản lý máy chủ từ xa.

![PostgreSQL](images/15-database-postgresql.png)

**PostgreSQL** có các nút: **Thêm CSDL**, **Mật khẩu superuser**, **Đồng bộ**, **Máy chủ từ xa**, **Nhập dữ liệu**. Bảng danh sách gồm tên CSDL, người dùng, mật khẩu, sao lưu, vị trí và dung lượng.

| MySQL | SQL Server |
| --- | --- |
| ![MySQL](images/11-database-mysql.png) | ![SQL Server](images/12-database-sqlserver.png) |

| MongoDB | Redis |
| --- | --- |
| ![MongoDB](images/13-database-mongodb.png) | ![Redis](images/14-database-redis.png) |

> [!CAUTION]
> tsPanel lưu dữ liệu của chính nó trong cơ sở dữ liệu PostgreSQL tên `tspanel`. Không xoá hay sửa cơ sở dữ liệu này.

**Kết nối từ dự án triển khai:** thông tin kết nối (ví dụ `DATABASE_URL=postgres://user:password@host:5432/dbname`) được khai báo trong tab **Biến môi trường** của dự án. Lưu ý: bên trong container, `localhost` và `127.0.0.1` trỏ tới chính container chứ không phải máy chủ. Có hai cách thường dùng:

- Khai báo cơ sở dữ liệu trong cùng tệp compose với ứng dụng.
- Dùng một cơ sở dữ liệu mà container truy cập được qua mạng.

---

## 8. Tên miền và chứng chỉ SSL

### 8.1 Nhà cung cấp DNS

Vào **Tên miền → DNS** để kết nối nhà cung cấp DNS và quản lý bản ghi ngay trong panel.

![DNS](images/68-domains-dns.png)

1. Bấm **Thêm** ở khung **Nhà cung cấp DNS**, chọn nhà cung cấp và nhập thông tin API. Với Cloudflare, tạo API Token tại **My Profile → API Tokens → Create Token**, dùng mẫu **Edit zone DNS**.
2. Bấm **Kiểm tra kết nối** để xác nhận panel truy cập được API.
3. Chọn zone (tên miền gốc) để xem bản ghi. Có thể lọc theo loại, tìm kiếm, **Thêm bản ghi**, sửa hoặc xoá bản ghi.

Cột **Proxy** cho biết bản ghi đi qua proxy của Cloudflare (**Proxy**) hay chỉ phân giải DNS (**Chỉ DNS**).

Nhà cung cấp DNS đã kết nối được dùng để tự tạo bản ghi A cho [tên miền của dự án triển khai](#55-tên-miền-và-https), và để xác minh DNS khi cấp chứng chỉ.

### 8.2 Chứng chỉ SSL

Vào **Tên miền → Chứng chỉ SSL** để xem danh sách chứng chỉ, gồm đơn vị cấp, hạn dùng, trạng thái tự gia hạn và ngày tạo. Mỗi chứng chỉ có các thao tác gia hạn, tải xuống, triển khai và xoá.

![Chứng chỉ SSL](images/69-domains-ssl-certificates.png)

Bấm **Cấp chứng chỉ** để xin chứng chỉ Let's Encrypt:

![Cấp chứng chỉ Let's Encrypt](images/70-domains-ssl-issue-dialog.png)

| Trường | Mô tả |
| --- | --- |
| Tên miền | Mỗi dòng một tên miền, hoặc phân tách bằng dấu phẩy. Tên miền wildcard (`*.example.com`) phải xác minh qua DNS |
| Phương thức xác minh | **Xác minh qua file (HTTP):** cần có website để lưu file challenge.<br>**Xác minh qua DNS:** hỗ trợ wildcard |
| Nhà cung cấp DNS | Nhà cung cấp đã kết nối, hoặc **Thủ công (tự thêm bản ghi TXT)**. Bản ghi TXT cần thêm sẽ hiện trong nhật ký tác vụ |
| Tự gia hạn trước khi hết hạn | Tự gia hạn chứng chỉ (chứng chỉ Let's Encrypt có hạn 90 ngày) |

---

## 9. Website

Menu **Website** có 5 tab: **Dự án PHP**, **Dự án Node.js**, **Dự án Proxy**, **Dự án Go**, **Dự án Python**. Các website này chạy sau Nginx (OpenResty) của máy chủ.

### 9.1 Dự án PHP

![Dự án PHP](images/04-website-php.png)

Các nút **Thêm website**, **Trang mặc định** và **Website mặc định**. Bảng danh sách gồm trạng thái, sao lưu, thư mục gốc, hạn dùng, phiên bản PHP và SSL. Có thể lọc theo danh mục hoặc tìm theo tên miền và ghi chú.

![Thêm website](images/05-website-add-dialog.png)

| Trường | Mô tả |
| --- | --- |
| Tên miền | Mỗi dòng một tên miền, mặc định dùng cổng 80. Dùng dạng `tenmien:cổng` cho cổng khác (`www.example.com:8080`), và `*.example.com` cho wildcard |
| Ghi chú | Mặc định lấy theo tên miền đầu tiên |
| Thư mục gốc | Mặc định nằm trong `/www/wwwroot/`, được tạo tự động nếu chưa có |
| Phiên bản PHP | Chọn phiên bản PHP đã cài, hoặc **Tĩnh** cho website HTML/CSS/JS |
| Danh mục | Dùng để phân nhóm website |
| Tạo tài khoản FTP / Tạo cơ sở dữ liệu MySQL | Tạo kèm tài khoản FTP và cơ sở dữ liệu riêng cho website. Nếu chưa cài Pure-FTPd hoặc MySQL, có liên kết **Cài ngay** |

### 9.2 Node.js, Proxy, Go, Python

| Tab | Chức năng | Màn hình |
| --- | --- | --- |
| **Dự án Node.js** | Chạy ứng dụng Node.js như một dịch vụ có tên miền. Nút **Phiên bản Node** dùng để quản lý phiên bản Node | ![Node.js](images/06-website-nodejs.png) |
| **Dự án Proxy** | Reverse proxy từ tên miền tới một địa chỉ nội bộ (ví dụ `http://127.0.0.1:3000`), có bật/tắt, SSL, log | ![Proxy](images/07-website-proxy.png) |
| **Dự án Go** | Chạy binary Go như một dịch vụ có tên miền | ![Go](images/08-website-go.png) |
| **Dự án Python** | Chạy ứng dụng Python (Flask, Django, FastAPI, …) như một dịch vụ có tên miền | ![Python](images/09-website-python.png) |

---

## 10. Tệp tin, Terminal và FTP

### 10.1 Tệp tin

![Trình quản lý tệp](images/57-files-browser.png)

- **Thanh điều hướng:** lùi, tiến, lên thư mục cha, làm mới, đường dẫn hiện tại, thêm vào yêu thích, dung lượng phân vùng.
- **Thanh công cụ:** **Tải lên**, **Tạo mới**, **Tải từ URL**, **Tìm nội dung**, **Yêu thích**, **Terminal** (mở terminal tại thư mục hiện tại), **Thùng rác**.
- **Bảng tệp:** kích thước, quyền / chủ sở hữu, thời gian sửa. Thao tác trên từng tệp gồm **Sửa**, **Đổi tên** và **Thêm**.

Trình soạn thảo hỗ trợ tô sáng cú pháp và mở nhiều tệp cùng lúc theo tab. Có **Lưu** (`Ctrl+S`), **Lưu tất cả** và **Tải lại từ đĩa**. Thanh trạng thái hiển thị ngôn ngữ, kiểu xuống dòng và mã hoá ký tự.

![Trình soạn thảo](images/58-files-editor.png)

> [!WARNING]
> Thư mục `/www/server/` chứa phần mềm do panel quản lý. Nên sao lưu tệp cấu hình trước khi sửa.

### 10.2 Terminal

![Terminal](images/71-terminal.png)

Terminal web mở phiên shell trên máy chủ với quyền `root`, hỗ trợ nhiều tab phiên.

- Tab **Host** lưu thông tin SSH của các máy chủ khác.
- Tab **Lệnh nhanh** lưu các lệnh thường dùng.

### 10.3 FTP

![FTP](images/10-ftp.png)

Quản lý tài khoản FTP cho từng website. Cần cài **Pure-FTPd** trước khi dùng.

---

## 11. Tác vụ định kỳ

Menu **Tác vụ định kỳ** có 3 tab: **Tác vụ**, **Luồng tác vụ**, **Thư viện script**.

![Tác vụ](images/72-cron-tasks.png)

Tab **Tác vụ** có các nút **Thêm tác vụ**, **Nhập**, **Xuất**, kèm bộ lọc theo loại, theo nhóm và ô tìm kiếm.

![Thêm tác vụ định kỳ](images/73-cron-task-add-dialog.png)

| Trường | Mô tả |
| --- | --- |
| Loại tác vụ | Chạy shell script, sao lưu website hoặc cơ sở dữ liệu, gọi URL, … |
| Nhóm | Dùng để phân nhóm tác vụ |
| Tên tác vụ | Tự điền theo loại và đối tượng, có thể sửa |
| Lịch chạy | Chu kỳ (ví dụ **Hằng ngày**), giờ, phút. Dòng mô tả bên dưới tóm tắt lịch đã chọn |
| Chạy với người dùng | Tài khoản hệ thống dùng để chạy script |
| Chèn từ thư viện script | Chèn script đã lưu trong thư viện |
| Nội dung script | Script bash. Tránh các lệnh phá huỷ như `shutdown`, `mkfs`, `passwd` |

| Luồng tác vụ | Thư viện script |
| --- | --- |
| ![Luồng tác vụ](images/74-cron-workflows.png) | ![Thư viện script](images/75-cron-script-library.png) |

- **Luồng tác vụ:** ghép nhiều tác vụ có sẵn để chạy theo thứ tự cố định, với lịch chạy và cách xử lý khi gặp lỗi.
- **Thư viện script:** lưu script (tên, danh mục, ngôn ngữ, mô tả) để dùng lại trong tác vụ.

---

## 12. Giám sát

![Giám sát](images/42-monitor.png)

- Chọn khoảng thời gian ở góc trên bên trái. Các nút **Làm mới**, **Cài đặt** và **Xoá lịch sử** ở góc trên bên phải.
- Biểu đồ **Mức dùng CPU**, **Mức dùng bộ nhớ**, **Tải hệ thống** (1/5/15 phút), **IO ổ đĩa** (đọc/ghi) và **Lưu lượng mạng** (tải lên/tải xuống).
- Mỗi biểu đồ hiển thị giá trị hiện tại, trung bình và đỉnh.

![Giám sát – IO đĩa và mạng](images/43-monitor-network-disk.png)

---

## 13. Nhật ký

| Mục | Nội dung |
| --- | --- |
| **Nhật ký panel → Thao tác** | Nhật ký kiểm toán: thời gian, người dùng, IP, module, hành động, chi tiết. Hỗ trợ xuất dữ liệu, xoá, lọc theo module và thời gian |
| **Nhật ký panel → Log vận hành** | Đầu ra của tiến trình panel: request HTTP, tác vụ theo lịch, tác vụ nền |
| **Nhật ký panel → Log lỗi** | Lỗi của tiến trình panel (định dạng JSON) |
| **Nhật ký website** | Phân tích access log và error log của từng website: số yêu cầu, IP duy nhất, lỗi client/server, băng thông, top IP và URL |
| **Kiểm tra log hệ thống** | Đọc các tệp log trong `/var/log` (syslog, auth, apt, …) |
| **Đăng nhập SSH** | Các lần đăng nhập SSH thành công và thất bại: người dùng, IP, cổng, phương thức |
| **Nhật ký phần mềm** | Log của các phần mềm cài từ Kho ứng dụng |

| Thao tác | Log vận hành |
| --- | --- |
| ![Thao tác](images/61-logs-panel-operations.png) | ![Log vận hành](images/62-logs-panel-runtime.png) |

| Log lỗi | Nhật ký website |
| --- | --- |
| ![Log lỗi](images/63-logs-panel-errors.png) | ![Nhật ký website](images/64-logs-website.png) |

| Log hệ thống | Đăng nhập SSH |
| --- | --- |
| ![Log hệ thống](images/65-logs-system-audit.png) | ![Đăng nhập SSH](images/66-logs-ssh-login.png) |

![Nhật ký phần mềm](images/67-logs-software.png)

---

## 14. WAF

WAF (tường lửa ứng dụng web) dùng engine **Coraza** và bộ luật **OWASP Core Rule Set**. WAF cần Nginx (OpenResty) và được cung cấp dưới dạng plugin (xem [Plugin](#18-cài-đặt-panel)).

![WAF – Tổng quan](images/44-waf-overview.png)

**Bật WAF:**

1. Vào **WAF → Tổng quan**, bật **Bật bảo vệ WAF** và chọn **Chế độ**.
2. Vào **WAF → Website**, bật WAF và chỉnh cài đặt riêng cho từng website.

Tab **Tổng quan** hiển thị trạng thái engine, phiên bản CRS, chế độ hoạt động và các số liệu: yêu cầu/giây, yêu cầu hôm nay, đã chặn, đã phát hiện, PV, UV, IP tấn công, lưu lượng. Có biểu đồ 7 ngày, biểu đồ theo giờ, và ô chọn node để xem thống kê.

| Tab | Chức năng |
| --- | --- |
| **Website** | Bật/tắt WAF và cài đặt riêng theo từng website |
| **Bảo vệ** | Mức độ nghiêm ngặt (1–4), ngưỡng điểm bất thường đầu vào/đầu ra, nhóm tấn công (SQLi, XSS, RCE, LFI/RFI, PHP, Java, session fixation, …), bộ loại trừ cho WordPress, Nextcloud, phpMyAdmin, Drupal, tắt luật theo ID |
| **Kiểm soát truy cập** | Danh sách cho phép / chặn theo IP (IPv4, IPv6, CIDR), tiền tố URL, User-Agent và header (biểu thức chính quy) |
| **Giới hạn tốc độ** | Số yêu cầu tối đa mỗi IP trong một khoảng thời gian, thời gian chặn, URI được miễn, ngưỡng tự động chặn IP |
| **Chặn theo quốc gia** | Chặn, hoặc chỉ cho phép, truy cập từ các quốc gia được chọn (dữ liệu DB-IP) |
| **Quy tắc tùy chỉnh** | Luật riêng, được xét trước OWASP CRS. Điều kiện kết hợp kiểu AND, kèm hành động khi khớp |
| **Nhật ký tấn công** | Lượt bị chặn và sự kiện chặn IP. Lọc theo node, website, nhóm luật, IP, khoảng ngày |
| **Lưu lượng** | Yêu cầu, đã chặn, đã phát hiện, băng thông, mã trạng thái, top IP, URL, trình duyệt/bot, nguồn giới thiệu |
| **Bản đồ tấn công** | Nguồn tấn công theo quốc gia trên bản đồ |
| **Báo cáo** | Báo cáo PV, UV, yêu cầu, lượt chặn theo khoảng ngày. Xuất CSV |
| **Cài đặt** | Cho qua khi lỗi (fail open), số ngày lưu nhật ký, xuất/nhập cấu hình, xoá dữ liệu WAF |

| Website | Bảo vệ |
| --- | --- |
| ![Website](images/45-waf-sites.png) | ![Bảo vệ](images/46-waf-protection.png) |

| Kiểm soát truy cập | Giới hạn tốc độ |
| --- | --- |
| ![Kiểm soát truy cập](images/47-waf-access-control.png) | ![Giới hạn tốc độ](images/48-waf-rate-limit.png) |

| Chặn theo quốc gia | Quy tắc tùy chỉnh |
| --- | --- |
| ![Chặn theo quốc gia](images/49-waf-geo-block.png) | ![Quy tắc tùy chỉnh](images/50-waf-custom-rules.png) |

![Thêm quy tắc tùy chỉnh](images/51-waf-custom-rule-dialog.png)

| Nhật ký tấn công | Lưu lượng |
| --- | --- |
| ![Nhật ký tấn công](images/52-waf-attack-log.png) | ![Lưu lượng](images/53-waf-traffic.png) |

| Bản đồ tấn công | Báo cáo |
| --- | --- |
| ![Bản đồ tấn công](images/54-waf-attack-map.png) | ![Báo cáo](images/55-waf-report.png) |

![Cài đặt WAF](images/56-waf-settings.png)

> [!TIP]
> Nếu WAF chặn nhầm một yêu cầu hợp lệ, hãy tìm ID luật trong **Nhật ký tấn công**, rồi tắt luật đó trong **Bảo vệ → Tắt luật theo ID**, hoặc giảm mức độ nghiêm ngặt.

---

## 15. Docker

Menu **Docker** có các tab: **Tổng quan**, **Container**, **Ứng dụng một chạm**, **Image trên cloud**, **Image cục bộ**, **Compose**, **Mạng**, **Volume**, **Registry**, **Cài đặt**.

![Docker – Tổng quan](images/16-docker-overview.png)

| Tab | Chức năng |
| --- | --- |
| **Tổng quan** | Phiên bản Docker Engine và Compose, nút khởi động lại/dừng, số container, image, mạng, volume, thông tin engine, dung lượng image/container/volume/build cache |
| **Container** | Chạy, dừng, khởi động lại, xem log, mở terminal, sửa, xoá container. Có **Tạo container** và dọn container đã dừng |
| **Ứng dụng một chạm** | Triển khai nhanh Adminer, MySQL, Nginx, PostgreSQL, Redis |
| **Image trên cloud** | Danh mục image dựng sẵn để triển khai |
| **Image cục bộ** | Image trên máy: tải về, xoá, dọn image không dùng |
| **Compose** | Quản lý dự án docker-compose |
| **Mạng** | Tạo và dọn mạng Docker |
| **Volume** | Tạo và dọn volume |
| **Registry** | Lưu thông tin đăng nhập registry riêng |
| **Cài đặt** | Sửa `daemon.json` ở dạng có cấu trúc hoặc JSON thô: registry mirror, registry không bảo mật, log driver, thư mục dữ liệu, live restore |

| Container | Tạo container |
| --- | --- |
| ![Container](images/17-docker-containers.png) | ![Tạo container](images/18-docker-container-create-dialog.png) |

| Ứng dụng một chạm | Image trên cloud |
| --- | --- |
| ![Ứng dụng một chạm](images/19-docker-one-click-apps.png) | ![Image trên cloud](images/20-docker-cloud-images.png) |

| Image cục bộ | Compose |
| --- | --- |
| ![Image cục bộ](images/21-docker-local-images.png) | ![Compose](images/22-docker-compose.png) |

| Mạng | Volume |
| --- | --- |
| ![Mạng](images/23-docker-networks.png) | ![Volume](images/24-docker-volumes.png) |

| Registry | Cài đặt |
| --- | --- |
| ![Registry](images/25-docker-registry.png) | ![Cài đặt Docker](images/26-docker-settings.png) |

> [!WARNING]
> Container có tên bắt đầu bằng `tspanel-deploy-` thuộc các dự án trong menu **Triển khai**. Hãy quản lý chúng từ trang dự án.

---

## 16. Node

Panel chính (master) quản lý thêm các máy chủ khác thông qua agent. Agent tự kết nối ngược về master, nên máy chủ được thêm vào không cần mở cổng đầu vào.

![Quản lý node](images/59-node-manage.png)

Mỗi thẻ node hiển thị trạng thái trực tuyến, IP, phiên bản, hệ điều hành/kiến trúc, mức dùng CPU, RAM, đĩa và lưu lượng mạng. Khi phiên bản agent lệch với master, thẻ hiện nhãn **Lệch phiên bản** cùng nút **Nâng cấp agent**.

**Thêm node:** bấm **Thêm node**. Quy trình gồm 3 bước: **Truy cập SSH → Cài agent → Plugin**.

![Thêm node](images/60-node-add-dialog.png)

| Trường | Mô tả |
| --- | --- |
| Tên node, Danh mục | Tên hiển thị và nhóm |
| Máy chủ (host), Cổng | Địa chỉ và cổng SSH của máy chủ cần thêm |
| Tên đăng nhập | Tài khoản SSH, mặc định `root` |
| Mật khẩu / Khoá riêng | Phương thức xác thực SSH |
| Lưu SSH | Lưu thông tin SSH vào node để dùng cho terminal và cài lại agent |

Chuyển giữa các máy chủ bằng ô **Master** ở góc trên bên trái.

---

## 17. Kho ứng dụng

![Kho ứng dụng](images/76-app-store.png)

- Nhóm: **Tất cả**, **Đã cài**, **Máy chủ web**, **Cơ sở dữ liệu**, **Môi trường chạy**, **Công cụ**, **Bảo mật**, **Triển khai**.
- Các nút **Cài đặt phần mềm**, **Làm mới danh sách** và ô tìm ứng dụng.
- Bảng danh sách gồm ứng dụng, nhà phát triển, phiên bản, vị trí, trạng thái, **Hiện ở trang chủ** và thao tác (**Thiết lập**, **Gỡ cài đặt**, **Cài đặt**).

Kho ứng dụng cài được Nginx (OpenResty), MySQL, MariaDB, PostgreSQL, Redis, Memcached, PHP 7.4 và 8.1–8.4, Pure-FTPd, phpMyAdmin, trình quản lý phiên bản Python và Go, …

- Đây là các **gói dựng sẵn**, tải từ `https://dl.mmoall.com`. Máy chủ không phải biên dịch gì cả.
- Trước khi cài, panel kiểm tra SHA-256 và chữ ký ed25519 của từng gói.
- Các gói cần glibc 2.31 trở lên.
- Danh sách gói hiện có nằm trong [`index.json`](https://dl.mmoall.com/index.json).

---

## 18. Cài đặt panel

Menu **Cài đặt** có các tab: **Chung**, **Giao diện**, **Cảnh báo**, **Sao lưu**, **Dịch vụ panel**, **Plugin**. Tab **Cảnh báo** và **Sao lưu** được mô tả ở [mục 4](#4-thiết-lập-ban-đầu).

### 18.1 Chung

| Nhóm | Trường |
| --- | --- |
| **Panel** | Tên panel, ngôn ngữ, thời gian hết phiên, thư mục gốc website, thư mục sao lưu, múi giờ, giờ máy chủ (**Đồng bộ ngay**), chế độ nhà phát triển |
| **Truy cập** | Cổng panel (**Đổi cổng**), IP máy chủ |
| **Bảo mật** | Tên đăng nhập, mật khẩu, URL đăng nhập, xác thực hai lớp, xác thực HTTP cơ bản, cảnh báo đăng nhập, hết hạn mật khẩu |
| **Chứng chỉ HTTPS của panel** | Chứng chỉ hiện tại, các tên miền/IP mà chứng chỉ áp dụng, hiệu lực, **Tải lên chứng chỉ** |

### 18.2 Chứng chỉ HTTPS của panel

Mặc định, panel dùng chứng chỉ tự ký. Để trình duyệt và các client MCP tin cậy kết nối, hãy tải lên chứng chỉ hợp lệ bằng **Tải lên chứng chỉ**. Thay đổi có hiệu lực ngay, không cần khởi động lại panel.

Có thể dùng chứng chỉ Let's Encrypt cấp tại **Tên miền → Chứng chỉ SSL** cho một tên miền trỏ về máy chủ (ví dụ `panel.example.com`), rồi truy cập panel qua tên miền đó.

### 18.3 Giao diện

![Giao diện](images/78-settings-appearance.png)

Chế độ **Sáng** / **Tối** / **Hệ thống**, màu nhấn, thu gọn thanh bên, tên hiển thị và logo, ẩn/hiện từng mục menu.

![Giao diện tối](images/84-dark-home.png)

### 18.4 Dịch vụ panel và Plugin

| Dịch vụ panel | Plugin |
| --- | --- |
| ![Dịch vụ panel](images/81-settings-panel-service.png) | ![Plugin](images/82-settings-plugins.png) |

- **Dịch vụ panel:** trạng thái, phiên bản, PID, thời gian hoạt động, cổng, số worker, CPU, RAM của tiến trình panel. Có nút xoá bộ nhớ đệm và xem log vận hành, log lỗi, log truy cập.
- **Plugin:** bật, tắt, cài hoặc gỡ tính năng tuỳ chọn (ví dụ WAF) mà không cần khởi động lại panel.

---

## 19. Xử lý sự cố

### 19.1 Sự cố thường gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| Trình duyệt cảnh báo kết nối không riêng tư | Panel đang dùng chứng chỉ tự ký. Chọn **Nâng cao → Tiếp tục**, hoặc tải lên chứng chỉ hợp lệ ([18.2](#182-chứng-chỉ-https-của-panel)) |
| Không mở được panel | Kiểm tra đang dùng đúng URL `Entrance`, mở cổng `8888/TCP` trên firewall của nhà cung cấp, kiểm tra service bằng `systemctl status tspanel` và xem cổng có đang lắng nghe không bằng `ss -ltnp \| grep 8888` |
| Quên mật khẩu hoặc URL đăng nhập | Dùng các lệnh ở [mục 19.2](#192-lệnh-quản-trị) |
| Service không khởi động | Xem log bằng `journalctl -u tspanel -n 200 --no-pager` và `/www/server/tspanel/data/logs/error.log` |
| Cài đặt báo `PostgreSQL server version is too old` | Hệ điều hành có PostgreSQL cũ hơn bản 14. Cài PostgreSQL 14+ từ [postgresql.org](https://www.postgresql.org/download/) rồi cài lại với `--db-url` ([mục 2.5](#dùng-postgresql-có-sẵn)) |
| Cài đặt báo `unsupported distribution for automatic PostgreSQL setup` | Tự cài PostgreSQL 14+ rồi cài lại với `--db-url` |
| Cài đặt báo `checksum mismatch` | File tải về bị lỗi hoặc không đầy đủ. Hãy chạy lại lệnh cài |
| Tên miền không truy cập được | Kiểm tra bản ghi A, chờ DNS cập nhật, kiểm tra đã **Lưu tên miền**, mở cổng 80 và 443 |
| Triển khai thất bại | Xem [mục 5.11](#511-lỗi-triển-khai-thường-gặp) |
| Dữ liệu ứng dụng mất sau khi triển khai lại | Xem [mục 5.12](#512-dữ-liệu-của-ứng-dụng) |
| Ổ đĩa đầy | Dọn image không dùng trong **Docker → Image cục bộ**, xoá bản sao lưu cũ, kiểm tra **Giám sát** |
| Client MCP báo lỗi | Xem bảng mã lỗi ở [mục 6.6](#66-bảo-mật-và-mã-lỗi) |

### 19.2 Lệnh quản trị

Lệnh `ts` được cài vào `/usr/local/bin/ts`. Chạy trên máy chủ với quyền `root` hoặc `sudo`:

| Mục đích | Lệnh |
| --- | --- |
| Đặt lại mật khẩu `admin` (tạo mật khẩu ngẫu nhiên mới) | `sudo ts reset-password admin` |
| Xem URL đăng nhập riêng và trạng thái bật/tắt | `sudo ts entrance show` |
| Tắt URL đăng nhập riêng (khi quên URL hoặc bị chặn) | `sudo ts entrance disable` |
| Xem phiên bản | `ts version` |
| Chạy migration cho database của panel | `sudo ts migrate` |
| Gỡ cài đặt panel | `sudo ts uninstall` |
| Trạng thái service | `sudo systemctl status tspanel` |
| Khởi động lại panel | `sudo systemctl restart tspanel` |
| Xem log service | `sudo journalctl -u tspanel -n 200 --no-pager` |
| Xem log trực tiếp | `sudo journalctl -u tspanel -f` |

### 19.3 Vị trí file

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

## 20. Nâng cấp

Bấm **Cập nhật** ở thanh trên cùng của panel, hoặc chạy lại lệnh cài đặt trên máy chủ:

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

## 21. Gỡ cài đặt

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

## Phụ lục: Thuật ngữ

| Thuật ngữ | Ý nghĩa |
| --- | --- |
| Máy chủ / VPS | Máy chủ Linux nơi cài tsPanel và các ứng dụng |
| Cổng (port) | Số hiệu dịch vụ mạng trên máy chủ. Panel mặc định dùng cổng `8888` |
| Tên miền | Tên dùng thay cho địa chỉ IP, ví dụ `example.com` |
| DNS, bản ghi A | Hệ thống phân giải tên miền. Bản ghi A ánh xạ một tên miền tới một địa chỉ IPv4 |
| SSL/TLS, HTTPS | Chứng chỉ dùng để mã hoá kết nối. Let's Encrypt cấp chứng chỉ miễn phí có hạn 90 ngày |
| Wildcard | Chứng chỉ hoặc tên miền áp dụng cho mọi tên miền con, dạng `*.example.com` |
| Repository (repo) | Kho mã nguồn Git, ví dụ trên GitHub |
| Docker image | Gói đóng sẵn ứng dụng cùng môi trường chạy |
| Container | Một phiên bản đang chạy của image |
| Dockerfile | Tệp mô tả cách build image |
| Compose | Tệp khai báo nhiều container chạy cùng nhau (`compose.yaml`) |
| Build | Quá trình tạo image từ mã nguồn |
| Triển khai (deploy) | Build và chạy một phiên bản ứng dụng |
| Rollback | Quay về một lần triển khai trước |
| Biến môi trường | Cặp khoá–giá trị truyền vào ứng dụng lúc chạy, thường chứa cấu hình và thông tin bí mật |
| Health check | Yêu cầu HTTP dùng để kiểm tra ứng dụng đã sẵn sàng |
| Reverse proxy | Máy chủ web nhận yêu cầu theo tên miền và chuyển tiếp tới ứng dụng đang chạy ở cổng nội bộ |
| Cron | Lịch chạy tác vụ định kỳ |
| MCP | Model Context Protocol, giao thức cho phép trợ lý AI gọi công cụ của hệ thống bên ngoài |
| Khoá API | Chuỗi bí mật dùng để xác thực client MCP |
| WAF | Tường lửa ứng dụng web, lọc các yêu cầu HTTP độc hại |
| OWASP CRS | Bộ luật phát hiện tấn công web dùng chung cho WAF |
| Node / Agent | Máy chủ phụ được panel chính quản lý thông qua chương trình agent |
| SSH | Giao thức đăng nhập và điều khiển máy chủ từ xa bằng dòng lệnh |

---

tsPanel được phát triển bởi [**TechShield**](https://techshield.vn).
