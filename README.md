# 🎬 YVD (YouTube Video Downloader)

A premium, sleek, and high-performance video downloading suite built with Flutter.

[![Build and Release](https://github.com/HexaGhost-09/YVD/actions/workflows/release.yml/badge.svg)](https://github.com/HexaGhost-09/YVD/actions/workflows/release.yml)

## ✨ Features

- **Premium UI**: Modern dark theme with glassmorphism and smooth animations.
- **Cross-Platform**: Support for Windows (EXE), Android (APK/AAB), and Linux.
- **Fast Analysis**: Quick video/audio analysis for multiple platforms.

## 🚀 Automated Releases

The project includes a GitHub Actions CI/CD pipeline that automatically builds and releases your application.

### How to trigger a release:
Simply tag your commit with `v*.*.*` and push it:
```bash
git tag v1.0.0
git push origin v1.0.0
```
This will automatically:
1.  **Build** APK (Android).
2.  **Build** Windows EXE.
3.  **Build** Linux Bundle.
4.  **Create** a GitHub Release with all the binaries attached.

## 🛠️ Getting Started

### Prerequisites:
- Flutter SDK (>= 3.10.7)
- Java 17 (for Android)
- Visual Studio (for Windows)
- Linux build dependencies (libgtk-3-dev, libblkid-dev, liblzma-dev, libgcrypt20-dev)

### Installation:
```bash
flutter pub get
flutter run
```

---
Built with ❤️ by [HexaGhost-09](https://github.com/HexaGhost-09)
