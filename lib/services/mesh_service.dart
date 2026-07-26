import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import '../protocol/cache/dedup_cache.dart';
import '../protocol/crypto/mesh_crypto.dart';
import '../protocol/identity/identity_storage.dart';
import '../protocol/identity/mesh_identity.dart';
import '../protocol/models/message_envelope.dart';
import '../protocol/relay/relay_engine.dart';
import '../protocol/serialization/envelope_serializer.dart';
import '../protocol/transport/chunk_model.dart';
import '../protocol/transport/chunker.dart';
import '../protocol/transport/reassembler.dart';
import '../storage/database_helper.dart';
import '../storage/models/peer.dart';
import '../storage/models/pending_message.dart';
import '../storage/models/stored_message.dart';
import '../storage/repositories/message_repository.dart';
import '../storage/repositories/peer_repository.dart';
import '../storage/repositories/pending_message_repository.dart';
import '../transport/android/android_ble_transport.dart';
import '../transport/ios/ios_ble_transport.dart';
import '../transport/mock_transport.dart';
import '../transport/transport_interface.dart';

/// Single entry point connecting UI ↔ Protocol ↔ Storage ↔ BLE Transport.
class MeshService extends ChangeNotifier {
  final IdentityStorageInterface identityStorage;
  final DatabaseHelper dbHelper;

  late MessageRepository messageRepo;
  late PeerRepository peerRepo;
  late PendingMessageRepository pendingRepo;

  late Transport transport;
  late DedupCache _dedupCache;
  late RelayEngine _relayEngine;
  late Reassembler _reassembler;

  MeshIdentity? _currentIdentity;
  bool _isInitialized = false;

  // Real-time streams
  final StreamController<StoredMessage> _messageReceivedCtrl =
      StreamController.broadcast();
  final StreamController<List<DiscoveredPeer>> _nearbyPeersCtrl =
      StreamController.broadcast();

  final Map<String, DiscoveredPeer> _activePeers = {};

  // Diagnostics counters
  int _totalRelayedCount = 0;
  int _totalSentCount = 0;
  int _totalReceivedCount = 0;

  MeshService({
    IdentityStorageInterface? identityStorage,
    DatabaseHelper? dbHelper,
    Transport? customTransport,
  })  : identityStorage = identityStorage ?? SecureIdentityStorage(),
        dbHelper = dbHelper ?? DatabaseHelper() {
    messageRepo = MessageRepository(this.dbHelper);
    peerRepo = PeerRepository(this.dbHelper);
    pendingRepo = PendingMessageRepository(this.dbHelper);

    if (customTransport != null) {
      transport = customTransport;
    } else if (!kIsWeb && Platform.isAndroid) {
      transport = AndroidBleTransport();
    } else if (!kIsWeb && Platform.isIOS) {
      transport = IosBleTransport();
    } else {
      transport = MockTransport();
    }
  }

  bool get isInitialized => _isInitialized;
  MeshIdentity? get currentIdentity => _currentIdentity;
  Stream<StoredMessage> get onMessageReceived => _messageReceivedCtrl.stream;
  Stream<List<DiscoveredPeer>> get nearbyPeersStream => _nearbyPeersCtrl.stream;
  List<DiscoveredPeer> get nearbyPeers => _activePeers.values.toList();
  int get totalRelayedCount => _totalRelayedCount;

  /// Initializes identity, protocol engines, storage, and BLE transport.
  Future<bool> initialize() async {
    _currentIdentity = await identityStorage.loadIdentity();
    if (_currentIdentity == null) {
      return false; // Requires onboarding identity creation
    }

    _setupProtocolEngines();
    // One-time migration: clean up legacy MAC-address peer entries
    await _cleanupLegacyPeers();
    await _startMeshTransport();
    _isInitialized = true;
    notifyListeners();
    return true;
  }

  /// Called after onboarding generates a new identity.
  Future<void> setIdentity(MeshIdentity identity) async {
    await identityStorage.saveIdentity(identity);
    _currentIdentity = identity;
    _setupProtocolEngines();
    await _startMeshTransport();
    _isInitialized = true;
    notifyListeners();
  }

  /// Updates the local user's display nickname.
  Future<void> updateNickname(String nickname) async {
    if (_currentIdentity == null) return;
    _currentIdentity = _currentIdentity!.copyWith(nickname: nickname);
    await identityStorage.saveIdentity(_currentIdentity!);
    notifyListeners();
  }

  void _setupProtocolEngines() {
    _dedupCache = DedupCache();
    _reassembler = Reassembler();
    _relayEngine = RelayEngine(
      myDeviceId: _currentIdentity!.deviceId,
      dedupCache: _dedupCache,
      signatureVerifier: _verifyMessageSignature,
    );
  }

  bool _transportStarted = false;
  final List<StreamSubscription> _transportSubs = [];

  Future<void> _startMeshTransport() async {
    if (_transportStarted) {
      // Already listening — just restart scan/advertise
      await transport.stopScanning();
      await transport.startAdvertising();
      await transport.startScanning();
      return;
    }
    _transportStarted = true;

    // Transport incoming data listener
    _transportSubs.add(transport.incomingData.listen(_handleIncomingBleData));

    // Peer discovered listener
    _transportSubs.add(transport.peerDiscovered.listen((peer) {
      _activePeers[peer.peerId] = peer;
      _nearbyPeersCtrl.add(_activePeers.values.toList());

      // Attempt store-and-forward outbox delivery
      _flushPendingMessagesForPeer(peer.peerId);
      _flushBroadcastPendingMessages();
      notifyListeners();
    }));

    // Peer lost listener
    _transportSubs.add(transport.peerLost.listen((peerId) {
      _activePeers.remove(peerId);
      _nearbyPeersCtrl.add(_activePeers.values.toList());
      notifyListeners();
    }));

    // Start BLE scanning and advertising
    await transport.startAdvertising();
    await transport.startScanning();
  }

  /// Process incoming raw BLE bytes chunk from a peer.
  Future<void> _handleIncomingBleData(
      ({String peerId, Uint8List data}) incoming) async {
    try {
      final chunk = MessageChunk.fromBytes(incoming.data);
      final completeEnvelopeBytes = _reassembler.addChunk(chunk);

      if (completeEnvelopeBytes == null) return; // Still buffering chunks

      final envelope = EnvelopeSerializer.decode(completeEnvelopeBytes);
      final decision = await _relayEngine.evaluate(envelope);

      if (decision.isDropped) return;

      // 1. Local display decision
      if (decision.shouldDisplayLocally) {
        _totalReceivedCount++;
        await _processIncomingMessage(envelope);
      }

      // 2. Rebroadcast decision (mesh relay hop)
      if (decision.envelopeToRebroadcast != null) {
        _totalRelayedCount++;
        final rebroadcastBytes =
            EnvelopeSerializer.encode(decision.envelopeToRebroadcast!);
        final chunks = Chunker.chunkEnvelope(
          messageId: decision.envelopeToRebroadcast!.messageId,
          payloadBytes: rebroadcastBytes,
        );
        for (final c in chunks) {
          await transport.broadcast(c.toBytes());
        }
      }
    } catch (e) {
      debugPrint('Error processing incoming mesh chunk: $e');
    }
  }

  /// Process fully verified and assembled envelope for local display & storage.
  Future<void> _processIncomingMessage(MessageEnvelope envelope) async {

    final existingPeer = await peerRepo.getPeerById(envelope.senderId);

    final updatedPublicKeyBase64 = envelope.senderPublicKey != null
        ? base64Encode(envelope.senderPublicKey!)
        : (existingPeer?.publicKeyBase64 ?? '');

    final updatedEncKeyBase64 = envelope.senderEncryptionKey != null
        ? base64Encode(envelope.senderEncryptionKey!)
        : existingPeer?.encryptionKeyBase64;

    final updatedNickname = (envelope.senderNickname != null && envelope.senderNickname!.isNotEmpty)
        ? envelope.senderNickname
        : existingPeer?.nickname;

    await peerRepo.upsertPeer(Peer(
      deviceId: envelope.senderId,
      publicKeyBase64: updatedPublicKeyBase64,
      encryptionKeyBase64: updatedEncKeyBase64,
      nickname: updatedNickname,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    ));

    String decryptedBody;

    if (envelope.recipientId == null) {
      // Broadcast message — cleartext UTF-8 string
      decryptedBody = utf8.decode(envelope.payload);
    } else {
      // Direct message — decrypt via X25519 / ChaCha20-Poly1305
      try {
        final senderEncKeyBytes = envelope.senderEncryptionKey ??
            (await peerRepo.getPeerById(envelope.senderId))?.encryptionKeyBytes;

        if (senderEncKeyBytes != null && senderEncKeyBytes.length >= 32) {
          final senderXKey = SimplePublicKey(
            senderEncKeyBytes,
            type: KeyPairType.x25519,
          );
          final decryptedBytes = await MeshCrypto.decryptDirectMessage(
            encryptedPayload: envelope.payload,
            recipientX25519KeyPair: _currentIdentity!.x25519KeyPair,
            senderX25519PublicKey: senderXKey,
          );
          decryptedBody = utf8.decode(decryptedBytes);
        } else {
          decryptedBody = utf8.decode(envelope.payload); // Cleartext fallback
        }
      } catch (e) {
        // Fallback to UTF-8 if unencrypted or error
        try {
          decryptedBody = utf8.decode(envelope.payload);
        } catch (_) {
          decryptedBody = '[Encrypted Message]';
        }
      }
    }

    final conversationId = envelope.recipientId == null
        ? 'broadcast'
        : envelope.senderId;

    final storedMsg = StoredMessage(
      id: envelope.messageId,
      conversationId: conversationId,
      senderId: envelope.senderId,
      recipientId: envelope.recipientId,
      body: decryptedBody,
      timestamp: envelope.timestamp,
      status: DeliveryStatus.delivered,
      direction: MessageDirection.incoming,
    );

    await messageRepo.insertMessage(storedMsg);
    _messageReceivedCtrl.add(storedMsg);
    notifyListeners();
  }

  /// Signature verification callback used by RelayEngine.
  ///
  /// Uses Trust-On-First-Use (TOFU): unknown peers are accepted to allow
  /// initial key exchange, but known peers with stored keys must pass
  /// Ed25519 signature verification. Crypto errors reject the message.
  Future<bool> _verifyMessageSignature({
    required String senderId,
    required Uint8List signableBytes,
    required Uint8List signature,
  }) async {
    final peer = await peerRepo.getPeerById(senderId);
    if (peer == null || peer.publicKeyBytes.length < 32) {
      // TOFU: Accept first message from unknown peers to allow key exchange
      debugPrint('Signature: TOFU accept for unknown/incomplete peer $senderId');
      return true;
    }

    try {
      final publicKey = SimplePublicKey(
        peer.publicKeyBytes,
        type: KeyPairType.ed25519,
      );
      return await MeshCrypto.verifySignature(
        bytes: signableBytes,
        signatureBytes: signature,
        publicKey: publicKey,
      );
    } catch (e) {
      debugPrint('Signature verification error for $senderId: $e');
      return false; // Reject messages with invalid/corrupt signatures
    }
  }

  /// Sends a new message (direct 1-on-1 or broadcast).
  Future<StoredMessage> sendMessage({
    required String? recipientId,
    required String body,
  }) async {
    if (_currentIdentity == null) {
      throw StateError('Identity not initialized');
    }

    final conversationId = recipientId ?? 'broadcast';
    final payloadBytes = Uint8List.fromList(utf8.encode(body));

    Uint8List envelopePayload;

    if (recipientId == null) {
      // Broadcast cleartext payload
      envelopePayload = payloadBytes;
    } else {
      // Direct message E2E encryption
      final peer = await peerRepo.getPeerById(recipientId);
      if (peer != null && peer.encryptionKeyBytes != null && peer.encryptionKeyBytes!.length >= 32) {
        final recipientXKey = SimplePublicKey(
          peer.encryptionKeyBytes!,
          type: KeyPairType.x25519,
        );
        envelopePayload = await MeshCrypto.encryptDirectMessage(
          plaintextPayload: payloadBytes,
          senderX25519KeyPair: _currentIdentity!.x25519KeyPair,
          recipientX25519PublicKey: recipientXKey,
        );
      } else {
        envelopePayload = payloadBytes; // Cleartext fallback until key exchange completes
      }
    }

    final edPubBytes = Uint8List.fromList(_currentIdentity!.ed25519PublicKey.bytes);
    final xPubBytes = Uint8List.fromList(_currentIdentity!.x25519PublicKey.bytes);

    final tempEnvelope = MessageEnvelope.create(
      senderId: _currentIdentity!.deviceId,
      senderNickname: _currentIdentity!.nickname,
      senderPublicKey: edPubBytes,
      senderEncryptionKey: xPubBytes,
      recipientId: recipientId,
      ttl: 6,
      payload: envelopePayload,
      signature: Uint8List(64), // Signature placeholder
    );

    final signature = await MeshCrypto.signBytes(
      bytes: tempEnvelope.getSignableBytes(),
      keyPair: _currentIdentity!.ed25519KeyPair,
    );

    final finalEnvelope = MessageEnvelope.create(
      messageId: tempEnvelope.messageId,
      senderId: _currentIdentity!.deviceId,
      senderNickname: _currentIdentity!.nickname,
      senderPublicKey: edPubBytes,
      senderEncryptionKey: xPubBytes,
      recipientId: recipientId,
      ttl: 6,
      timestamp: tempEnvelope.timestamp,
      payload: envelopePayload,
      signature: signature,
    );

    // Register our own message in dedup cache so we don't process rebroadcasted loops of it
    _dedupCache.add(finalEnvelope.messageId);

    final storedMsg = StoredMessage(
      id: finalEnvelope.messageId,
      conversationId: conversationId,
      senderId: _currentIdentity!.deviceId,
      recipientId: recipientId,
      body: body,
      timestamp: finalEnvelope.timestamp,
      status: DeliveryStatus.pending,
      direction: MessageDirection.outgoing,
    );

    await messageRepo.insertMessage(storedMsg);
    _totalSentCount++;

    final serializedEnvelope = EnvelopeSerializer.encode(finalEnvelope);
    final chunks = Chunker.chunkEnvelope(
      messageId: finalEnvelope.messageId,
      payloadBytes: serializedEnvelope,
    );

    // Try sending over active transport if any connected peer/relay is available
    final hasActiveConnections = transport.connectedPeers.isNotEmpty;

    if (hasActiveConnections) {
      for (final chunk in chunks) {
        if (recipientId != null) {
          await transport.send(recipientId, chunk.toBytes());
        } else {
          await transport.broadcast(chunk.toBytes());
        }
        await Future.delayed(const Duration(milliseconds: 12));
      }
      await messageRepo.updateStatus(finalEnvelope.messageId, DeliveryStatus.sent);
    } else {
      // Store and forward outbox queue
      await pendingRepo.enqueue(PendingMessage(
        messageId: finalEnvelope.messageId,
        recipientId: recipientId ?? 'broadcast',
        envelopeBytes: serializedEnvelope,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        expiresAt: DateTime.now()
            .add(PendingMessageRepository.defaultExpiry)
            .millisecondsSinceEpoch,
      ));
    }

    notifyListeners();
    return storedMsg;
  }

  /// Flushes pending outbox messages when a target peer comes into range.
  Future<void> _flushPendingMessagesForPeer(String peerId) async {
    final pendingList = await pendingRepo.getForRecipient(peerId);
    for (final pending in pendingList) {
      try {
        final chunks = Chunker.chunkEnvelope(
          messageId: pending.messageId,
          payloadBytes: pending.envelopeBytes,
        );
        for (final c in chunks) {
          await transport.send(peerId, c.toBytes());
        }
        await pendingRepo.remove(pending.messageId);
        await messageRepo.updateStatus(pending.messageId, DeliveryStatus.sent);
      } catch (_) {
        await pendingRepo.markAttempt(pending.messageId);
      }
    }
  }

  /// Flushes pending broadcast messages when any peer becomes available.
  Future<void> _flushBroadcastPendingMessages() async {
    if (transport.connectedPeers.isEmpty) return;

    final pendingList = await pendingRepo.getForRecipient('broadcast');
    for (final pending in pendingList) {
      try {
        final chunks = Chunker.chunkEnvelope(
          messageId: pending.messageId,
          payloadBytes: pending.envelopeBytes,
        );
        for (final c in chunks) {
          await transport.broadcast(c.toBytes());
        }
        await pendingRepo.remove(pending.messageId);
        await messageRepo.updateStatus(pending.messageId, DeliveryStatus.sent);
      } catch (_) {
        await pendingRepo.markAttempt(pending.messageId);
      }
    }
  }

  /// One-time migration: remove MAC-address-based peer entries from earlier versions.
  Future<void> _cleanupLegacyPeers() async {
    try {
      final legacyPeers = await peerRepo.getAllPeers();
      for (final p in legacyPeers) {
        if (p.deviceId.contains(':')) {
          await peerRepo.deletePeer(p.deviceId);
        }
      }
    } catch (e) {
      debugPrint('Legacy peer cleanup error: $e');
    }
  }

  /// Diagnostics metadata summary.
  Future<Map<String, dynamic>> getMeshDiagnostics() async {
    final pendingCount = await pendingRepo.count();
    final pendingMessagesCount = await messageRepo.countByStatus(DeliveryStatus.pending);
    final deliveredMessagesCount = await messageRepo.countByStatus(DeliveryStatus.delivered);

    return {
      'deviceId': _currentIdentity?.deviceId ?? 'Unknown',
      'isActive': transport.isActive,
      'connectedPeersCount': transport.connectedPeers.length,
      'connectedPeers': transport.connectedPeers.toList(),
      'pendingOutboxCount': pendingCount,
      'totalSent': _totalSentCount,
      'totalReceived': _totalReceivedCount,
      'totalRelayed': _totalRelayedCount,
      'pendingMessagesCount': pendingMessagesCount,
      'deliveredMessagesCount': deliveredMessagesCount,
    };
  }

  @override
  void dispose() {
    for (final sub in _transportSubs) {
      sub.cancel();
    }
    _transportSubs.clear();
    transport.dispose();
    _messageReceivedCtrl.close();
    _nearbyPeersCtrl.close();
    super.dispose();
  }
}
