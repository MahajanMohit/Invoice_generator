# Shakti Invoice - Android App (Flutter)

A fully offline Android app for Shakti General Store, converted from the original Python Flask web app.

## Features
- Create invoices with customer name, date/time, and line items
- Live grand total calculation
- Auto invoice numbering (SGS-001, SGS-002, ...)
- PDF receipt generation (58mm thermal receipt style)
- Share or open PDF after generation
- Invoice history grouped by date (Today / Yesterday / date)

## Tech Stack
| Component | Library |
|-----------|---------|
| UI | Flutter / Material 3 |
| Database | sqflite (SQLite) |
| PDF | pdf package |
| Share | share_plus |
| Open PDF | open_filex |

## Setup & Build

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, ≥3.0)
2. Install [Android Studio](https://developer.android.com/studio) with Android SDK
3. Accept Android licenses: `flutter doctor --android-licenses`

### Run on a device / emulator
```bash
cd shakti_invoice
flutter pub get
flutter run
```

### Build a release APK
```bash
flutter build apk --release
# APK location: build/outputs/flutter-apk/app-release.apk
```

### Build an App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

## Project Structure
```
lib/
├── main.dart                  # App entry point
├── models/
│   ├── invoice.dart           # Invoice data model
│   └── invoice_item.dart      # InvoiceItem data model
├── database/
│   └── database_helper.dart   # SQLite operations (mirrors app.py DB logic)
├── services/
│   └── pdf_service.dart       # PDF generation (mirrors generate_receipt_pdf)
└── screens/
    ├── home_screen.dart       # Invoice creation form (mirrors index.html + script.js)
    └── history_screen.dart    # Invoice history list (mirrors sidebar)
```

## Data Storage
- SQLite database at: `<app_documents>/databases/invoices.db`
- PDFs saved at: `<app_documents>/invoices/YYYYMM/<invoice>.pdf`
