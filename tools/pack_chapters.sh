#!/usr/bin/env bash
set -euo pipefail

# Thư mục gốc chứa các chapter:
SRC_DIR="assets/videos"
# Thư mục build output (tính từ root repo):
OUT_DIR="build/packs"

# Tạo OUT_DIR ở root repo
mkdir -p "$OUT_DIR"

# Danh sách chapter cần pack (1..6):
CHAPTERS=(chapter1 chapter2 chapter3 chapter4 chapter5 chapter6)

# Xoá file cũ
rm -f "$OUT_DIR"/*.zip "$OUT_DIR"/*.sha256 "$OUT_DIR"/sizes.txt

# Hàm lấy sha256 tương thích macOS/Linux
sha256_of() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    echo "Không tìm thấy shasum/sha256sum" >&2
    exit 1
  fi
}

for ch in "${CHAPTERS[@]}"; do
  ZIP_FILE="$OUT_DIR/${ch}.zip"
  echo ">> Zipping $ch -> $ZIP_FILE"

  # Dùng OLPDWD để tham chiếu OUT_DIR tuyệt đối khi cd vào SRC_DIR
  (
    cd "$SRC_DIR"
    # Gói nguyên thư mục 'chapterN' để giữ cấu trúc chapterN/...
    zip -r "$OLDPWD/$ZIP_FILE" "$ch" >/dev/null
  )

  # Tính sha256 và size
  SHASUM=$(sha256_of "$ZIP_FILE")
  echo "$SHASUM  $(basename "$ZIP_FILE")" > "$OUT_DIR/${ch}.zip.sha256"

  # Ghi size (byte) - macOS: stat -f%z ; Linux: stat -c%s
  SIZE=$(stat -f%z "$ZIP_FILE" 2>/dev/null || stat -c%s "$ZIP_FILE")
  echo "$(basename "$ZIP_FILE") $SIZE" >> "$OUT_DIR/sizes.txt"
done

echo ">> Done. Packs ở: $OUT_DIR/"
echo "   Liệt kê nhanh:"
ls -lh "$OUT_DIR"
