import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bitmsg/protocol/crypto/mesh_crypto.dart';
import 'package:bitmsg/protocol/identity/identity_storage.dart';
import 'package:bitmsg/protocol/identity/mesh_identity.dart';
import 'package:bitmsg/protocol/models/message_envelope.dart';
import 'package:bitmsg/protocol/serialization/envelope_serializer.dart';
import 'package:bitmsg/protocol/transport/chunker.dart';
import 'package:bitmsg/services/mesh_service.dart';
import 'package:bitmsg/storage/database_helper.dart';
import 'package:bitmsg/storage/models/stored_message.dart';
import 'package:bitmsg/transport/mock_transport.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper dbHelper;
  late InMemoryIdentityStorage identityStorage;
  late MockTransport mockTransport;
  late MeshService meshService;

  setUp(() async {
    dbHelper = DatabaseHelper(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    identityStorage = InMemoryIdentityStorage();
    mockTransport = MockTransport();

    meshService = MeshService(
      identityStorage: identityStorage,
      dbHelper: dbHelper,
      customTransport: mockTransport,
    );
  });

  tearDown(() async {
    await dbHelper.close();
    meshService.dispose();
  });

  group('MeshService Integration Tests', () {
    test('initialize requires identity setup on first run', () async {
      final initialized = await meshService.initialize();
      expect(initialized, isFalse);
      expect(meshService.currentIdentity, isNull);

      final newIdentity = await MeshIdentity.generate();
      await meshService.setIdentity(newIdentity);

      expect(meshService.isInitialized, isTrue);
      expect(meshService.currentIdentity, isNotNull);
      expect(meshService.currentIdentity!.deviceId, equals(newIdentity.deviceId));
    });

    test('sendMessage creates pending stored message and broadcasts over transport', () async {
      final identity = await MeshIdentity.generate();
      await meshService.setIdentity(identity);

      final msg = await meshService.sendMessage(
        recipientId: null, // Broadcast
        body: 'Hello mesh broadcast!',
      );

      expect(msg.body, equals('Hello mesh broadcast!'));
      expect(msg.direction, equals(MessageDirection.outgoing));

      final history = await meshService.messageRepo.getConversationHistory('broadcast');
      expect(history.length, equals(1));
      expect(history.first.body, equals('Hello mesh broadcast!'));
    });

    test('receiving message chunks over BLE triggers onMessageReceived and SQLite insert', () async {
      final senderIdentity = await MeshIdentity.generate();
      final myIdentity = await MeshIdentity.generate();

      await meshService.setIdentity(myIdentity);

      // Create an envelope from senderIdentity
      final payload = Uint8List.fromList('Test incoming message'.codeUnits);
      final tempEnvelope = MessageEnvelope.create(
        senderId: senderIdentity.deviceId,
        recipientId: myIdentity.deviceId,
        ttl: 5,
        payload: payload,
        signature: Uint8List(64),
      );

      final signature = await MeshCrypto.signBytes(
        bytes: tempEnvelope.getSignableBytes(),
        keyPair: senderIdentity.ed25519KeyPair,
      );

      final envelope = MessageEnvelope.create(
        messageId: tempEnvelope.messageId,
        senderId: senderIdentity.deviceId,
        recipientId: myIdentity.deviceId,
        ttl: 5,
        timestamp: tempEnvelope.timestamp,
        payload: payload,
        signature: signature,
      );

      final envelopeBytes = EnvelopeSerializer.encode(envelope);
      final chunks = Chunker.chunkEnvelope(
        messageId: envelope.messageId,
        payloadBytes: envelopeBytes,
      );

      // Simulate incoming BLE chunk from mock transport
      for (final chunk in chunks) {
        mockTransport.simulateIncomingData(senderIdentity.deviceId, chunk.toBytes());
      }

      await Future.delayed(const Duration(milliseconds: 50));

      final history = await meshService.messageRepo.getConversationHistory(senderIdentity.deviceId);
      expect(history.length, equals(1));
      expect(history.first.body, equals('Test incoming message'));
    });

    test('getMeshDiagnostics returns statistics map', () async {
      final identity = await MeshIdentity.generate();
      await meshService.setIdentity(identity);

      final stats = await meshService.getMeshDiagnostics();
      expect(stats['deviceId'], equals(identity.deviceId));
      expect(stats['isActive'], isTrue);
      expect(stats.containsKey('totalSent'), isTrue);
      expect(stats.containsKey('totalRelayed'), isTrue);
    });
  });
}
