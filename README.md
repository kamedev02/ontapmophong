# 🛣️ Flutter Driving Simulation for Vietnamese License Test

**Mô phỏng các tình huống nguy hiểm trong học & thi bằng lái xe tại Việt Nam**
Ứng dụng được phát triển bằng **Flutter Desktop**, dành cho cộng đồng học viên, đặc biệt là **người dùng macOS** – hiện chưa được hỗ trợ chính thức bởi Bộ Công An.

> ⚠️ Đây **không phải** là phiên bản chính thức của Bộ Công An, mà là dự án mã nguồn mở nhằm phục vụ mục đích học tập, nghiên cứu và ôn luyện cá nhân.

---

## 🚀 Tính năng

- 🎮 Mô phỏng trực quan các **tình huống nguy hiểm thường gặp** trong đề thi bằng lái xe.
- 🧩 Hệ thống câu hỏi và video được thiết kế mở — có thể dễ dàng cập nhật/tùy chỉnh.
- 💻 Chạy được trên **Windows**, **macOS**, và **Linux**.
- 🧠 Dữ liệu (video/tình huống) được tải qua Git LFS hoặc tải riêng nếu bạn clone dự án.

---

## 🧱 Cấu trúc dự án

```txt
├── android/
├── assets
│   ├── data.json
│   ├── icon-180x180.png
│   ├── icon-192x192.png
│   ├── icon-270x270.png
│   └── icon-32x32.png
├── ios/
├── lib
│   ├── core
│   │   ├── constants
│   │   │   └── app_strings.dart
│   │   └── services
│   │       └── file_downloader.dart
│   ├── features
│   │   └── simulation
│   │       ├── pages
│   │       │   └── simulation_page.dart
│   │       ├── provider
│   │       │   └── simulation_provider.dart
│   │       └── widgets
│   │           ├── custom_flag.dart
│   │           ├── download_indicator.dart
│   │           ├── left_panel.dart
│   │           ├── quiz_content_view.dart
│   │           ├── review_content_view.dart
│   │           ├── right_panel.dart
│   │           ├── segment_bar.dart
│   │           ├── slider_theme_data.dart
│   │           └── video_player_panel.dart
│   ├── models
│   │   ├── chapter.dart
│   │   └── situation.dart
│   ├── widgets
│   │   └── group_box.dart
│   └── main.dart
├── linux/
├── macos/
├── test
│   └── widget_test.dart
├── web/
├── windows/
├── .gitattributes
├── .gitignore
├── .metadata
├── README.md
├── analysis_options.yaml
├── pubspec.lock
└── pubspec.yaml
```

---

## ⚙️ Cài đặt và chạy thử

### Yêu cầu

- Flutter SDK ≥ 3.19
- Git LFS đã cài đặt:

    ```bash
    git lfs install
    ```

### Clone và tải dữ liệu

```bash
git clone https://github.com/<your-username>/<repo-name>.git
cd <repo-name>
git lfs pull
```

Nếu dữ liệu được chia nhỏ trong `artifacts/`, bạn có thể giải nén:

```bash
7z x artifacts/dataset.7z.001 -odata
# hoặc:
unzip artifacts/dataset.zip -d data
```

### Chạy ứng dụng

```bash
flutter pub get
flutter run -d macos    # hoặc windows / linux tùy nền tảng
```

---

## 🤝 Đóng góp

Mọi ý kiến đóng góp, pull request hoặc issue đều được hoan nghênh!
Bạn có thể:

- 🐛 Báo lỗi (bug report)
- 💡 Đề xuất tính năng mới
- 🎥 Thêm dữ liệu video/tình huống mới
- 🧑‍💻 Cải thiện UI/UX hoặc hiệu năng

Vui lòng đảm bảo code tuân thủ chuẩn `flutter format` và `dart analyze`.

---

## 📦 Dữ liệu (Data Package)

Do dung lượng lớn (~3GB), dữ liệu mô phỏng được lưu trữ bằng **Git LFS** và có thể được chia nhỏ trong thư mục `artifacts/`.
Nếu GitHub hạn chế băng thông, bạn có thể tải thủ công từ phần **Releases**.

---

## ⚖️ Lưu ý pháp lý

Ứng dụng này:

- Không đại diện cho Bộ Công An hoặc bất kỳ cơ quan nhà nước nào.
- Chỉ nhằm mục đích học tập, ôn thi, và nghiên cứu kỹ thuật mô phỏng.
- Không được sử dụng cho mục đích thương mại hoặc gây hiểu nhầm về nguồn gốc.

> Mọi nội dung video, âm thanh hoặc dữ liệu được chia sẻ trong dự án này đều tuân thủ nguyên tắc sử dụng hợp lý (fair use) và có thể bị gỡ bỏ nếu vi phạm bản quyền.

---

## 📜 Giấy phép

Dự án được phát hành theo giấy phép [MIT License](LICENSE).

---

## 💡 Ghi chú

Nếu bạn là người học bằng lái và đang sử dụng macOS — đây là giải pháp giúp bạn ôn tập hiệu quả mà không cần Windows.
Hãy ủng hộ dự án bằng cách ⭐️ **star repo này** nếu bạn thấy hữu ích!

---

### © 2025 – Flutter Driving Simulation Project

Made with ❤️ by the open-source community.
