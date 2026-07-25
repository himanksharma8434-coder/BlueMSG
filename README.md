# bitmsg — Offline Bluetooth Mesh Messaging App

**bitmsg** is a cross-platform (Android & iOS) Flutter application that enables nearby devices to exchange end-to-end encrypted text messages completely offline using Bluetooth Low Energy (BLE) as transport and a store-and-forward mesh relay protocol.

---

## Key Features

- **100% Offline & Serverless**: No internet, cell tower, account, or central server required.
- **Cryptographic Identity**: Generates Ed25519 signing keypairs and X25519 encryption keypairs locally on first launch.
- **End-to-End Encryption (E2E)**: Direct messages are encrypted using X25519 ECDH key agreement + ChaCha20-Poly1305 AEAD.
- **Mesh Relay Protocol**: Devices act as both BLE Centrals (scanners/clients) and Peripherals (advertisers/GATT servers). Messages hop through intermediate devices (TTL-based flooding) to reach peers out of direct range.
- **Compact CBOR Binary Encoding**: Protocol envelopes are encoded into compact binary CBOR streams with packet chunking/reassembly for BLE MTU limits (~185-500 bytes).
- **Deduplication Cache**: LRU capacity bounds and time-window eviction (15 min) prevent infinite loops or duplicate displays.
- **Local Persistence (SQLite)**: Message history, contacts, and a store-and-forward pending outbox are saved locally using `sqflite`.
- **Android & iOS Dual-Mode BLE**:
  - **Android**: `flutter_blue_plus` central mode + native Kotlin `BluetoothGattServer` peripheral mode + persistent `BleForegroundService`.
  - **iOS**: Native Swift `CoreBluetooth` (`CBCentralManager` + `CBPeripheralManager`) with state restoration.

---

## Architecture Overview

```
 ┌─────────────────────────────────────────────────────────┐
 │                       Flutter UI                        │
 │  (Onboarding, Conversations, Chat, Discovery, Diagnostics) │
 └────────────────────────────┬────────────────────────────┘
                              │
 ┌────────────────────────────▼────────────────────────────┐
 │                       MeshService                       │
 └──────┬─────────────────────┬────────────────────┬───────┘
        │                     │                    │
 ┌──────▼──────┐       ┌──────▼──────┐      ┌──────▼──────┐
 │  Protocol   │       │   SQLite    │      │  Platform   │
 │   Engine    │       │ Storage Repos│      │ BLE Transport│
 └─────────────┘       └─────────────┘      └─────────────┘
```

- **Protocol Engine** (`lib/protocol/`): `MessageEnvelope`, `EnvelopeSerializer`, `Chunker`, `Reassembler`, `DedupCache`, `RelayEngine`, `MeshCrypto`, `MeshIdentity`.
- **Storage Repositories** (`lib/storage/`): `MessageRepository`, `PeerRepository`, `PendingMessageRepository`, `DatabaseHelper`.
- **Platform Transport** (`lib/transport/`): `AndroidBleTransport`, `IosBleTransport`, `MockTransport`.

---

## Getting Started

### Prerequisites
- Flutter SDK 3.10.1 or newer
- Android SDK 23+ (Android 6.0+)
- iOS 13.0+ / Xcode 14+

### Running the App

```bash
# Fetch dependencies
flutter pub get

# Run unit and integration tests (43 tests)
flutter test

# Run on an Android device
flutter run -d <android-device-id>

# Run on an iOS device
flutter run -d <ios-device-id>
```

---

## Known Platform Limitations & Best Practices

1. **BLE Transmission Range**: Typical indoor BLE range is ~10–30 meters (up to 50m line-of-sight outdoors).
2. **iOS Background Constraints**:
   - iOS background advertising uses an overflow area — service UUIDs are not broadcast in full format to non-iOS scanners when backgrounded.
   - Background scanning requires pre-declared service UUIDs.
   - **Recommendation**: Keep the app open/foregrounded for optimal mesh relay performance.
3. **Android Battery Optimization**: On Android 12+, turn off OS battery optimization for bitmsg so `BleForegroundService` runs continuously.
4. **Physical Device Testing**: BLE cannot be tested on emulators or simulators; use real hardware.
