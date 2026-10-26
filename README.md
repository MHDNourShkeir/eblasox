# 🧦 EblaSox - Factory Management System

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![BLoC](https://img.shields.io/badge/State_Management-BLoC-blue?style=for-the-badge)

EblaSox is a comprehensive, enterprise-level Flutter application designed specifically for factory and manufacturing management. It features a highly dynamic, centralized configuration system where all app settings, paths, and user credentials are controlled remotely via an Excel file hosted on an SMB server.

## ✨ Key Features

### 🔄 Dynamic Configuration Sync (The "Magic")
The entire application is driven by a remote `config.xlsx` file. No app updates are required when adding new image folders, changing server IPs, or updating admin passwords.
* **Auto-Sync:** The app checks the `version` key in the Excel file on launch. If the server version is higher than the local version, the app automatically syncs the new configurations.
* **Session Management:** Major configuration changes force a user logout to ensure everyone is operating on the latest settings.
* **Emergency Fallback:** A hidden, password-protected management screen allows IT to manually override the SMB Host IP if the server network changes abruptly.

### 👥 Smart Authentication
* Users and passwords are dynamically loaded from the server's Excel file.
* Automatically handles data duplication (e.g., identical names in the Excel file) using advanced Set filtering to prevent UI dropdown crashes.
* Modern, flat-design minimalist login interface.

### 🖼️ Article & Model Catalog
* Connects directly to the factory's SMB server to scan specific subfolders dynamically.
* Recursively indexes `.jpg`, `.png`, and `.webp` files.
* Features real-time search, quick-preview dialogs, and high-quality image viewing.

### 📊 Manufacturing Orders (Excel Parser)
* Scans the server for manufacturing orders (`.xlsx` files).
* Uses **Dart Isolates (`compute`)** to parse heavy Excel files in the background, keeping the UI perfectly smooth.
* Extracts complex order details, sizes, colors, and even embedded media (images within the Excel archives) seamlessly.

### 💰 Employee Advances Management
* Tailored for department managers. Reads allowed advance amounts per manager dynamically.
* Generates and exports a new Excel sheet (`ManagerName YYYY-MM-DD.xlsx`) directly to the server.
* Built-in duplicate prevention: Managers cannot submit advances more than once a day.

### 🧮 Dozen Calculator
* A custom-built calculator specifically tailored for the textile/manufacturing industry to calculate dozens and fractions.
* Features a custom industrial 1-2-3 keypad layout with dedicated `/12` action keys.

## 🏗️ Architecture & Tech Stack

This project follows **Clean Architecture** principles and heavily utilizes the **BLoC/Cubit** pattern for state management, ensuring a strict separation between business logic and UI.

* **Framework:** Flutter (Dart)
* **State Management:** `flutter_bloc`
* **Network Protocol:** `smb_connect` (for direct Local Area Network file sharing)
* **Data Parsing:** `excel`, `archive` (for extracting media from `.xlsx` ZIP structures)
* **Local Caching:** `shared_preferences`

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (Latest Stable)
* An active SMB Server (Windows Share, NAS, or Linux Samba) with a `config.xlsx` file set up in the root directory.

### Installation
1. Clone the repository:
   
```bash
   git clone [https://github.com/yourusername/eblasox.git](https://github.com/yourusername/eblasox.git)
