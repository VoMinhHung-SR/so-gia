# Sổ giá thông minh (`so_gia`)

App Flutter offline-first cho người bán chợ/tạp hóa: quét barcode, sổ giá nhập theo nhà cung cấp, máy tính giá bán, đơn giá quy đổi, giá tham chiếu siêu thị.

Plan: `../plans/[UnDone] so-gia-thong-minh-MASTER.plan.md`

## Môi trường

Toolchain nằm trên ổ dữ liệu (ổ hệ thống gần đầy):

```bash
source /mnt/d9817672-fa4f-44b5-96e9-07bd39acf312/dev-tools/env.sh   # đã thêm vào ~/.bashrc
flutter doctor
```

## Demo trên máy (không cần điện thoại)

```bash
flutter run -d linux    # cửa sổ desktop
# hoặc
flutter run -d chrome
```

## Lệnh thường dùng

```bash
flutter pub get
dart run build_runner build      # sinh code Drift (*.g.dart)
flutter analyze
flutter test
flutter run -d linux
flutter build apk --debug
```
