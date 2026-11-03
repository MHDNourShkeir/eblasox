
# 🧦 EblaSox — Factory Management System

![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![State Management](https://img.shields.io/badge/State%20Management-BLoC%2FCubit-blue?style=for-the-badge)
![Network](https://img.shields.io/badge/Network-SMB-2E8B57?style=for-the-badge)

EblaSox is a Flutter application designed to manage factory operations and employee administration. It connects to a shared SMB server and uses Excel workbooks as a configurable source for application settings, user accounts, permissions, employee records, and operational data.

## ✨ Features

### 🔄 Centralized Configuration and SMB Connectivity
- Loads server connection details and application paths from a centralized configuration.
- Synchronizes configuration when the application starts.
- Supports configurable folders and subfolders for image catalogs and Excel documents.
- Includes a settings screen for managing connection and folder settings.
- Supports local configuration values through SharedPreferences.

### 🔐 Authentication and Role-Based Access
- Loads user accounts from the `users` worksheet in the server's Excel configuration workbook.
- Restores existing login sessions automatically.
- Reads each user's screen permissions from the configuration workbook.
- Supports separate access permissions for:
    - Image and model catalog.
    - Excel documents.
    - Employee management.
    - Dozen calculator.
- Saves the current user's permissions locally.
- Refreshes permissions from the server during authentication.
- Prevents unauthorized users from accessing restricted sections.
- Supports logout and session clearing.

### 🖼️ Article and Model Catalog
- Scans configured SMB folders and their subfolders recursively.
- Finds supported image formats:
    - JPG
    - JPEG
    - PNG
    - WebP
- Displays discovered images in an organized catalog.
- Provides search functionality.
- Supports image previews and viewing.

### 📊 Manufacturing Documents and Excel Viewer
- Scans configured SMB folders recursively for Excel workbooks.
- Supports XLSX and XLS file discovery.
- Opens manufacturing documents directly from the SMB share.
- Parses workbook content, including:
    - Order information.
    - Sizes.
    - Colors.
    - Embedded media where supported by the workbook parser.
- Uses background processing for heavy Excel parsing to help keep the interface responsive.

### 👥 Employee Management

#### 💰 Employee Advances Management
- Loads employees and advance options assigned to the signed-in manager.
- Allows advance amounts to be selected for individual employees.
- Calculates the total requested advances automatically.
- Exports submitted advances to an Excel workbook on the server.
- Prevents a manager from submitting advances more than once on the same day.
- Respects the management-controlled open/closed state of the advances process.
- Provides feedback when an export succeeds or fails.

#### ⏱️ Daily Working-Hours Recording
- Loads daily working-hours data from monthly Excel workbooks on the SMB server.
- Displays workers belonging to the signed-in supervisor's section.
- Allows working hours to be entered or updated for each worker.
- Supports selecting dates within the current month, up to the current date.
- Provides a quick action to set workers with no entered hours to 9 hours.
- Checks the current Excel values before saving.
- Avoids rewriting the workbook when no values have changed.
- Updates only changed cells.
- Preserves existing cell formatting when updating values.
- Displays feedback for successful saves, unchanged data, and errors.

### 🧮 Dozen Calculator
- Provides a calculator designed for textile and manufacturing calculations.
- Supports dozens and fractional calculations.
- Includes a custom industrial numeric keypad.
- Provides dedicated `/12` action keys.

### ⚙️ Management and Settings
- Allows administrators to manage application settings.
- Reads SMB connection settings dynamically.
- Supports configuring article image folders.
- Supports configuring Excel document folders.
- Allows management of administrative settings.
- Uses centralized configuration values instead of hardcoding server paths throughout the application.

## 🏗️ Architecture and Technology

The application uses a modular structure with Cubit-based state management to separate business logic from the user interface.

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application framework |
| Dart | Programming language |
| flutter_bloc | State management using BLoC/Cubit |
| smb_connect | SMB server connectivity and file operations |
| excel | Excel workbook reading and writing |
| archive | Extracting embedded media from Excel archives |
| shared_preferences | Local settings and session storage |
| intl | Date formatting and localization |

### Main Project Structure

```text
lib/
├── core/
│   └── config_sync_manager/
│       ├── config_sync_manager.dart
│       └── role_manager/
│           └── role_manager.dart
│
├── screens/
│   ├── auth/
│   │   ├── auth_cubit.dart
│   │   └── login_screen.dart
│   │
│   ├── home/
│   │   └── home_screen.dart
│   │
│   ├── article_image/
│   │   ├── article_cubit.dart
│   │   └── article_search.dart
│   │
│   ├── excel_search_screen/
│   │   ├── excel_viewer_cubit.dart
│   │   └── excel_search.dart
│   │
│   ├── employee_management/
│   │   ├── employees_dashboard.dart
│   │   └── advances/
│   │
│   ├── recording_hours/
│   │   ├── daily_hours_cubit.dart
│   │   ├── daily_hours_screen.dart
│   │   └── worker_hour_model.dart
│   │
│   ├── calculator/
│   │   └── calculator_screen.dart
│   │
│   └── management/
│       ├── mangement_cubit.dart
│       └── management_screen.dart
│
└── main.dart
```

## 🚀 Getting Started

### Prerequisites

Before running the application, make sure you have:

- Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml`.
- Dart SDK.
- Android Studio or Visual Studio Code.
- Access to an SMB server or shared network folder.
- A server-side Excel configuration workbook.
- Correct SMB host, username, password, and remote folder paths.

### Installation

1. Clone the repository:

```bash
git clone https://github.com/MHDNourShkeir/eblasox.git
```

2. Navigate to the project directory:

```bash
cd eblasox
```

3. Install dependencies:

```bash
flutter pub get
```

4. Configure the SMB server and workbook paths using the application's configuration workflow or the configuration workbook expected by the project.

5. Run the application:

```bash
flutter run
```

### Build Android APK

For a release APK:

```bash
flutter build apk --release
```

For a debug APK:

```bash
flutter build apk --debug
```

## 📁 Server Configuration

The application depends on a shared SMB server for its main operational features.

The server-side configuration workbook contains application settings and a `users` worksheet.

### User Permissions

The `users` worksheet stores usernames, passwords, and screen permissions.

The permission system uses screen IDs:

| Screen ID | Screen |
|---|---|
| 1 | Images and Models |
| 2 | Excel Documents |
| 3 | Employee Management |
| 4 | Dozen Calculator |

The application reads screen IDs from the worksheet header and treats `YES` as an enabled permission.

Each user can have a different set of accessible screens.

### Important Notes
- Make sure the SMB server is accessible from the device running the application.
- Ensure configured folder paths match the actual server paths.
- Keep the configuration workbook available to the application.
- Do not commit real SMB credentials or administrative passwords to source control.

## 🔒 Security Considerations

- User permissions are managed through the server configuration workbook.
- Session information is stored locally using SharedPreferences.
- Permissions are refreshed from the server during authentication.
- Unauthorized screens are blocked by the role-management logic.
- Administrative and SMB credentials should be protected and never exposed in public repositories.

---

## 📌 Future Improvements

Potential enhancements for future releases:

- Audit logs for attendance changes and advance submissions.
- More detailed reports and statistics.
- Automatic backup of operational Excel files.
- Improved offline support and synchronization.
- More advanced user and role management.
- Exportable attendance reports.

---

**EblaSox** — Factory Management System built with Flutter, Excel, and SMB connectivity.
