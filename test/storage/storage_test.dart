import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bitmsg/storage/database_helper.dart';
import 'package:bitmsg/storage/models/stored_message.dart';
import 'package:bitmsg/storage/models/peer.dart';
import 'package:bitmsg/storage/models/pending_message.dart';
import 'package:bitmsg/storage/repositories/message_repository.dart';
import 'package:bitmsg/storage/repositories/peer_repository.dart';
import 'package:bitmsg/storage/repositories/pending_message_repository.dart';

void main() {
  // Use FFI for desktop/test SQLite
  sqfliteFfiInit();

  late DatabaseHelper dbHelper;
  late MessageRepository messageRepo;
  late PeerRepository peerRepo;
  late PendingMessageRepository pendingRepo;

  setUp(() async {
    dbHelper = DatabaseHelper(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    messageRepo = MessageRepository(dbHelper);
    peerRepo = PeerRepository(dbHelper);
    pendingRepo = PendingMessageRepository(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('MessageRepository Tests', () {
    test('insert and retrieve a message', () async {
      final msg = StoredMessage(
        id: 'msg-001',
        conversationId: 'peer-abc',
        senderId: 'my-device-id',
        recipientId: 'peer-abc',
        body: 'Hello from the mesh!',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: DeliveryStatus.pending,
        direction: MessageDirection.outgoing,
      );

      await messageRepo.insertMessage(msg);
      final retrieved = await messageRepo.getMessageById('msg-001');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('msg-001'));
      expect(retrieved.body, equals('Hello from the mesh!'));
      expect(retrieved.status, equals(DeliveryStatus.pending));
      expect(retrieved.direction, equals(MessageDirection.outgoing));
    });

    test('update delivery status', () async {
      final msg = StoredMessage(
        id: 'msg-002',
        conversationId: 'peer-xyz',
        senderId: 'my-device-id',
        body: 'Test status update',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: DeliveryStatus.pending,
        direction: MessageDirection.outgoing,
      );

      await messageRepo.insertMessage(msg);
      await messageRepo.updateStatus('msg-002', DeliveryStatus.delivered);

      final updated = await messageRepo.getMessageById('msg-002');
      expect(updated!.status, equals(DeliveryStatus.delivered));
    });

    test('get conversation history returns messages newest-first', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 5; i++) {
        await messageRepo.insertMessage(StoredMessage(
          id: 'conv-msg-$i',
          conversationId: 'conv-123',
          senderId: i.isEven ? 'me' : 'them',
          body: 'Message $i',
          timestamp: now + (i * 1000),
          status: DeliveryStatus.delivered,
          direction: i.isEven ? MessageDirection.outgoing : MessageDirection.incoming,
        ));
      }

      final history = await messageRepo.getConversationHistory('conv-123');
      expect(history.length, equals(5));
      // Newest first
      expect(history.first.id, equals('conv-msg-4'));
      expect(history.last.id, equals('conv-msg-0'));
    });

    test('duplicate message insert is ignored', () async {
      final msg = StoredMessage(
        id: 'dup-msg-001',
        conversationId: 'peer-dup',
        senderId: 'sender',
        body: 'Original',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: DeliveryStatus.pending,
        direction: MessageDirection.incoming,
      );

      await messageRepo.insertMessage(msg);
      // Insert same ID again with different body — should be ignored
      await messageRepo.insertMessage(StoredMessage(
        id: 'dup-msg-001',
        conversationId: 'peer-dup',
        senderId: 'sender',
        body: 'Duplicate attempt',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: DeliveryStatus.pending,
        direction: MessageDirection.incoming,
      ));

      final retrieved = await messageRepo.getMessageById('dup-msg-001');
      expect(retrieved!.body, equals('Original'));
    });

    test('countByStatus returns correct counts', () async {
      await messageRepo.insertMessage(StoredMessage(
        id: 'status-1',
        conversationId: 'c',
        senderId: 's',
        body: 'b',
        timestamp: 1,
        status: DeliveryStatus.pending,
        direction: MessageDirection.outgoing,
      ));
      await messageRepo.insertMessage(StoredMessage(
        id: 'status-2',
        conversationId: 'c',
        senderId: 's',
        body: 'b',
        timestamp: 2,
        status: DeliveryStatus.pending,
        direction: MessageDirection.outgoing,
      ));
      await messageRepo.insertMessage(StoredMessage(
        id: 'status-3',
        conversationId: 'c',
        senderId: 's',
        body: 'b',
        timestamp: 3,
        status: DeliveryStatus.delivered,
        direction: MessageDirection.outgoing,
      ));

      expect(await messageRepo.countByStatus(DeliveryStatus.pending), equals(2));
      expect(await messageRepo.countByStatus(DeliveryStatus.delivered), equals(1));
      expect(await messageRepo.countByStatus(DeliveryStatus.failed), equals(0));
    });
  });

  group('PeerRepository Tests', () {
    test('upsert and retrieve a peer', () async {
      final peer = Peer(
        deviceId: 'device-abc',
        publicKeyBase64: 'cHVia2V5MTIz',
        nickname: 'Alice',
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      await peerRepo.upsertPeer(peer);
      final retrieved = await peerRepo.getPeerById('device-abc');

      expect(retrieved, isNotNull);
      expect(retrieved!.deviceId, equals('device-abc'));
      expect(retrieved.nickname, equals('Alice'));
    });

    test('upsert updates existing peer', () async {
      final peer = Peer(
        deviceId: 'device-update',
        publicKeyBase64: 'a2V5MQ==',
        nickname: 'Bob',
        lastSeen: 1000,
      );

      await peerRepo.upsertPeer(peer);
      await peerRepo.upsertPeer(peer.copyWith(nickname: 'Bobby', lastSeen: 2000));

      final retrieved = await peerRepo.getPeerById('device-update');
      expect(retrieved!.nickname, equals('Bobby'));
      expect(retrieved.lastSeen, equals(2000));
    });

    test('getAllPeers returns peers ordered by lastSeen DESC', () async {
      await peerRepo.upsertPeer(Peer(
        deviceId: 'old-peer',
        publicKeyBase64: 'a2V5MQ==',
        lastSeen: 1000,
      ));
      await peerRepo.upsertPeer(Peer(
        deviceId: 'new-peer',
        publicKeyBase64: 'a2V5Mg==',
        lastSeen: 5000,
      ));
      await peerRepo.upsertPeer(Peer(
        deviceId: 'mid-peer',
        publicKeyBase64: 'a2V5Mw==',
        lastSeen: 3000,
      ));

      final peers = await peerRepo.getAllPeers();
      expect(peers.length, equals(3));
      expect(peers[0].deviceId, equals('new-peer'));
      expect(peers[1].deviceId, equals('mid-peer'));
      expect(peers[2].deviceId, equals('old-peer'));
    });

    test('updateNickname works', () async {
      await peerRepo.upsertPeer(Peer(
        deviceId: 'nick-test',
        publicKeyBase64: 'a2V5MQ==',
        nickname: 'Original',
      ));

      await peerRepo.updateNickname('nick-test', 'Updated Name');

      final peer = await peerRepo.getPeerById('nick-test');
      expect(peer!.nickname, equals('Updated Name'));
    });

    test('deletePeer removes the peer', () async {
      await peerRepo.upsertPeer(Peer(
        deviceId: 'delete-me',
        publicKeyBase64: 'a2V5MQ==',
      ));

      expect(await peerRepo.getPeerById('delete-me'), isNotNull);
      await peerRepo.deletePeer('delete-me');
      expect(await peerRepo.getPeerById('delete-me'), isNull);
    });
  });

  group('PendingMessageRepository Tests', () {
    test('enqueue and retrieve pending messages for a recipient', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pending = PendingMessage(
        messageId: 'pending-001',
        recipientId: 'target-device',
        envelopeBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        createdAt: now,
        expiresAt: now + 86400000, // +24h
      );

      await pendingRepo.enqueue(pending);
      final retrieved = await pendingRepo.getForRecipient('target-device');

      expect(retrieved.length, equals(1));
      expect(retrieved.first.messageId, equals('pending-001'));
      expect(retrieved.first.envelopeBytes, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
    });

    test('markAttempt increments retryCount', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await pendingRepo.enqueue(PendingMessage(
        messageId: 'retry-test',
        recipientId: 'target',
        envelopeBytes: Uint8List.fromList([10]),
        createdAt: now,
        expiresAt: now + 86400000,
      ));

      await pendingRepo.markAttempt('retry-test');
      await pendingRepo.markAttempt('retry-test');

      final all = await pendingRepo.getAllPending();
      final msg = all.firstWhere((m) => m.messageId == 'retry-test');
      expect(msg.retryCount, equals(2));
      expect(msg.lastAttemptAt, isNotNull);
    });

    test('remove deletes a pending message', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await pendingRepo.enqueue(PendingMessage(
        messageId: 'remove-me',
        recipientId: 'target',
        envelopeBytes: Uint8List.fromList([1]),
        createdAt: now,
        expiresAt: now + 86400000,
      ));

      await pendingRepo.remove('remove-me');
      final result = await pendingRepo.getForRecipient('target');
      expect(result, isEmpty);
    });

    test('expired messages are excluded from queries', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Already expired
      await pendingRepo.enqueue(PendingMessage(
        messageId: 'expired-msg',
        recipientId: 'target',
        envelopeBytes: Uint8List.fromList([1]),
        createdAt: now - 100000,
        expiresAt: now - 1, // Already expired
      ));

      // Still valid
      await pendingRepo.enqueue(PendingMessage(
        messageId: 'valid-msg',
        recipientId: 'target',
        envelopeBytes: Uint8List.fromList([2]),
        createdAt: now,
        expiresAt: now + 86400000,
      ));

      final pending = await pendingRepo.getForRecipient('target');
      expect(pending.length, equals(1));
      expect(pending.first.messageId, equals('valid-msg'));
    });

    test('purgeExpired removes expired and exhausted-retry messages', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await pendingRepo.enqueue(PendingMessage(
        messageId: 'purge-expired',
        recipientId: 'target',
        envelopeBytes: Uint8List.fromList([1]),
        createdAt: now - 100000,
        expiresAt: now - 1,
      ));

      await pendingRepo.enqueue(PendingMessage(
        messageId: 'purge-valid',
        recipientId: 'target',
        envelopeBytes: Uint8List.fromList([2]),
        createdAt: now,
        expiresAt: now + 86400000,
      ));

      final purged = await pendingRepo.purgeExpired();
      expect(purged, equals(1));

      final remaining = await pendingRepo.count();
      expect(remaining, equals(1));
    });
  });
}
