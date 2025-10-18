# Content Data Pack (v25.10.1)

Phiên bản này chỉ bao gồm **dữ liệu video mô phỏng** được chia thành 6 gói (chapter packs) để sử dụng trong ứng dụng ôn tập mô phỏng thi bằng lái xe Việt Nam.
Không chứa mã nguồn hay bản cập nhật phần mềm.

---

## Nội dung

- 6 chapter packs (`chapter1.zip` → `chapter6.zip`), mỗi pack tương ứng với một chương trong `data.json`.
- `manifest.json` — chứa thông tin checksum (`sha256`), kích thước và URL tải của từng pack.
- `data.json` — cấu trúc ánh xạ `chapterX/thY/*.m3u8`, dùng để player trong ứng dụng truy cập đúng nội dung.

---

## Cách sử dụng

1. Ứng dụng của bạn sẽ tải `manifest.json` từ release này:
   [download](https://github.com/kamedev02/ontapmophong/releases/download/v25.10.1/manifest.json "manifest.json")

2. Khi người dùng mở một tình huống (TH), app sẽ:

- Kiểm tra pack chứa chương tương ứng (`chapterN`).
- Nếu pack chưa có cục bộ, tự động tải file `.zip`, xác minh checksum (`sha256`) và giải nén.
- Phát video từ thư mục nội bộ `videos_mophong/chapterN/thM/*.m3u8`.

---

## Thông tin kỹ thuật

- Dữ liệu gốc: [videos_mophong.zip](https://media.githubusercontent.com/media/kamedev02/ontapmophong/ccbb995d0d8946754707db7ae57e9d093ecd4e00/assets/videos_mophong.zip "videos_mophong.zip")
- Tổng dung lượng: ~1.7 GB (chia nhỏ thành 6 pack)

---

## Lịch sử thay đổi

- **v25.10.1** — Phát hành bản đầu tiên chứa toàn bộ dữ liệu video mô phỏng (no code changes).

---

> Nếu bạn muốn cập nhật nội dung video sau này, chỉ cần thay pack bị thay đổi và cập nhật `manifest.json` với version mới (`vYY.MM.N`). Trong đó: YY là hai chữ số cuối của năm; MM là tháng (01-12); N là số thứ tự release trong tháng (1 -> bản đầu tiên tháng 10).
