# Phase 6 — Manual Test Plan & Validation Guide

This document outlines the manual test procedures required to validate physical BLE mesh networking, store-and-forward relaying, deduplication, and cross-platform Android/iOS behavior for **bitmsg**.

> [!IMPORTANT]
> **Hardware Requirement**: BLE mesh networking requires at least **3 physical devices** (Android or iOS). BLE scanning, advertising, and GATT server operation cannot be tested on emulators or simulators.

---

## Test Scenarios Matrix

| Test ID | Scenario | Expected Outcome | Verification |
|---------|----------|------------------|--------------|
| **TC-01** | **Direct 2-Device Exchange** | Devices A & B exchange E2E encrypted messages in direct range (~5m). | Delivery icon changes to `Delivered` (✅). |
| **TC-02** | **3-Device Mesh Hop Relay** | Devices A & C out of range; Device B relays message from A → C. | Device C receives message; Device B increments `Total Relayed Hops`. |
| **TC-03** | **Store-and-Forward Outbox** | Device A sends message to offline Device C; auto-delivers when C connects. | Outbox status moves from `Pending` (⏳) → `Delivered` (✅). |
| **TC-04** | **Deduplication Loop Check** | Ring network (A, B, C, D all in range); A broadcasts with TTL=6. | Message displayed **exactly once** on all devices; duplicate hops dropped. |
| **TC-05** | **Android Background Service** | App backgrounded on Android; persistent notification remains active. | Device continues relaying messages in background via `BleForegroundService`. |
| **TC-06** | **iOS Background Constraints** | App backgrounded on iOS; foreground banner warning displayed. | User informed mesh relay works best with app in foreground. |

---

## Step-by-Step Test Instructions

### TC-01: Direct 2-Device Message Exchange
1. Launch **bitmsg** on Device A and Device B.
2. Complete onboarding on both devices to generate cryptographic identities.
3. Tap **Discover Peers** on Device A. Confirm Device B appears with RSSI signal meter.
4. Tap Device B to open direct chat.
5. Send `"Hello offline world!"`.
6. **Verify**:
   - Device B receives the message and displays `"Hello offline world!"`.
   - Security header displays `🔒 End-to-End Encrypted via X25519 + ChaCha20-Poly1305`.
   - Device A's message status icon changes to `Delivered` (✅).

---

### TC-02: 3-Device Mesh Hop Relay (A → B → C)
1. Position Device A and Device C 40–50 meters apart (or separated by thick walls) so they cannot see each other in BLE scan.
2. Place Device B halfway between A and C (in range of both).
3. On Device A, compose a direct message addressed to Device C.
4. Tap **Send**.
5. **Verify**:
   - Device A transmits chunks to Device B (TTL = 6).
   - Device B receives chunks, sees `recipientId == Device C`, decrements TTL to 5, and rebroadcasts.
   - Device C receives chunks from Device B, reassembles envelope, and displays the message.
   - Open **Mesh Diagnostics** on Device B: `Total Relayed Hops` counter is incremented by 1.

---

### TC-03: Store-and-Forward Offline Outbox
1. Turn off Bluetooth / power off Device C.
2. On Device A, send a direct message to Device C.
3. **Verify**:
   - Device A stores the message locally with status `Pending` (⏳).
   - Open **Mesh Diagnostics** on Device A: `Pending Outbox Count` = 1.
4. Turn Bluetooth back on on Device C.
5. **Verify**:
   - Device A detects Device C via `peerDiscovered` event.
   - Device A automatically flushes the outbox and delivers the message to Device C.
   - Message status on Device A updates to `Delivered` (✅).

---

### TC-04: Deduplication Mesh Loop Prevention
1. Place Devices A, B, C, D in a close circle (all in direct range).
2. On Device A, open the **Public Broadcast Room** and send `"Mesh flooding test"`.
3. Devices B, C, D all receive the broadcast simultaneously and attempt to rebroadcast with decremented TTL.
4. **Verify**:
   - `DedupCache` registers `messageId` on first arrival on all devices.
   - Duplicate copies received from other relay hops are silently dropped.
   - The message appears **only once** in the timeline on all 4 devices without duplicate entries or UI flickering.

---

### TC-05: Android Background Operation
1. On an Android device running bitmsg, press Home to background the app.
2. Pull down the Android notification shade.
3. **Verify**:
   - Persistent notification appears: `"bitmsg Mesh Active — Relaying messages to nearby devices"`.
4. Have another device send a broadcast message.
5. **Verify**:
   - The backgrounded Android device receives and relays the message to other nearby nodes.

---

### TC-06: Battery & Performance Monitoring
1. Run bitmsg continuously for 30 minutes in a multi-peer environment.
2. Open **Mesh Diagnostics** to verify metrics:
   - `Connected Peers Count` matches physical count.
   - No memory leaks or unresponsive UI during continuous scanning.
