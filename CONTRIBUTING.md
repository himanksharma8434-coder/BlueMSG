# Contributing to bitmsg

First off, thank you for considering contributing to **bitmsg**! This project was built primarily for educational purposes to demonstrate offline mesh networking, BLE, and cryptography in Flutter. We welcome contributions from developers, students, and security enthusiasts of all skill levels.

## How Can I Contribute?

### 1. Reporting Bugs
If you find a bug, please open an issue in the repository. Include as much detail as possible:
- Steps to reproduce the bug
- Device model and OS version (Android/iOS)
- Expected behavior vs. actual behavior
- Logs or screenshots if applicable

### 2. Suggesting Enhancements
Have an idea to improve the mesh routing protocol or optimize background BLE scanning? We'd love to hear it! Open an issue describing your proposed feature, why it would be useful, and how you envision it working.

### 3. Submitting Pull Requests
If you want to contribute code, please follow these steps:
1. **Fork the repository** and create your branch from `main`.
2. **Name your branch** descriptively (e.g., `feature/optimize-ble-scanning` or `fix/dedup-cache-eviction`).
3. **Write clear, concise commit messages**.
4. **Ensure your code passes all tests** by running `flutter test`. If you add new functionality, please add accompanying unit or integration tests.
5. **Format your code** using `flutter format .` and ensure no analyzer warnings are present (`flutter analyze`).
6. **Open a Pull Request (PR)** against the `main` branch. Provide a clear description of what your PR does and link to any relevant issues.

## Development Setup

1. Make sure you have the Flutter SDK (3.10.1+) installed.
2. Clone the repository and run `flutter pub get`.
3. To test BLE functionality, you will need **real physical devices**. Emulators and simulators do not support Bluetooth.
4. For iOS development, you will need a Mac with Xcode and an active Apple Developer account to provision the app onto a physical iPhone/iPad.

## Code of Conduct

As an educational open-source project, we are committed to providing a welcoming and inspiring community for all. Please be respectful, constructive, and patient when interacting with other contributors and reviewers.

Thank you for helping make bitmsg better!
