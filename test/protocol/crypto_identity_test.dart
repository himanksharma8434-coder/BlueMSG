import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitmsg/protocol/crypto/mesh_crypto.dart';
import 'package:bitmsg/protocol/identity/identity_storage.dart';
import 'package:bitmsg/protocol/identity/mesh_identity.dart';

void main() {
  group('Cryptographic Identity & E2E Encryption Tests', () {
    test('MeshIdentity.generate creates valid keypairs and 16-char hex deviceId', () async {
      final identity = await MeshIdentity.generate();

      expect(identity.deviceId, isNotEmpty);
      expect(identity.deviceId.length, equals(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(identity.deviceId), isTrue);
    });

    test('MeshIdentity can be exported to private bytes and reconstructed accurately', () async {
      final original = await MeshIdentity.generate();

      final edPriv = await original.getEd25519PrivateBytes();
      final xPriv = await original.getX25519PrivateBytes();

      final reconstructed = await MeshIdentity.fromPrivateKeyBytes(
        ed25519PrivateBytes: edPriv,
        x25519PrivateBytes: xPriv,
      );

      expect(reconstructed.deviceId, equals(original.deviceId));
      
      final reconstructedEdPub = reconstructed.ed25519PublicKey.bytes;
      final originalEdPub = original.ed25519PublicKey.bytes;
      expect(reconstructedEdPub, equals(originalEdPub));
    });

    test('InMemoryIdentityStorage correctly saves and loads identity', () async {
      final storage = InMemoryIdentityStorage();
      expect(await storage.loadIdentity(), isNull);

      final identity = await MeshIdentity.generate();
      await storage.saveIdentity(identity);

      final loaded = await storage.loadIdentity();
      expect(loaded, isNotNull);
      expect(loaded!.deviceId, equals(identity.deviceId));
    });

    test('Ed25519 signature generation and verification', () async {
      final alice = await MeshIdentity.generate();
      final messageBytes = Uint8List.fromList('Hello mesh network!'.codeUnits);

      final signature = await MeshCrypto.signBytes(
        bytes: messageBytes,
        keyPair: alice.ed25519KeyPair,
      );

      expect(signature, isNotEmpty);

      // Verify with Alice's public key -> true
      final isValid = await MeshCrypto.verifySignature(
        bytes: messageBytes,
        signatureBytes: signature,
        publicKey: alice.ed25519PublicKey,
      );
      expect(isValid, isTrue);

      // Verify with Bob's public key -> false
      final bob = await MeshIdentity.generate();
      final isValidBob = await MeshCrypto.verifySignature(
        bytes: messageBytes,
        signatureBytes: signature,
        publicKey: bob.ed25519PublicKey,
      );
      expect(isValidBob, isFalse);
    });

    test('X25519 + ChaCha20-Poly1305 E2E Direct Message Encryption between Alice and Bob', () async {
      final alice = await MeshIdentity.generate();
      final bob = await MeshIdentity.generate();

      final plaintext = Uint8List.fromList('Secret 1-on-1 direct offline message'.codeUnits);

      // Alice encrypts for Bob
      final encrypted = await MeshCrypto.encryptDirectMessage(
        plaintextPayload: plaintext,
        senderX25519KeyPair: alice.x25519KeyPair,
        recipientX25519PublicKey: bob.x25519PublicKey,
      );

      expect(encrypted, isNot(equals(plaintext)));

      // Bob decrypts from Alice
      final decrypted = await MeshCrypto.decryptDirectMessage(
        encryptedPayload: encrypted,
        recipientX25519KeyPair: bob.x25519KeyPair,
        senderX25519PublicKey: alice.x25519PublicKey,
      );

      expect(decrypted, equals(plaintext));
      expect(String.fromCharCodes(decrypted), equals('Secret 1-on-1 direct offline message'));
    });
  });
}
