import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../identity/mesh_identity.dart';

/// Cryptographic operations for signing, verification, and E2E encryption in bitmsg.
class MeshCrypto {
  static final Ed25519 _ed25519 = Ed25519();
  static final X25519 _x25519 = X25519();
  static final Cipher _cipher = Chacha20.poly1305Aead();

  /// Signs raw bytes using an Ed25519 keypair.
  static Future<Uint8List> signBytes({
    required Uint8List bytes,
    required SimpleKeyPair keyPair,
  }) async {
    final signature = await _ed25519.sign(bytes, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verifies an Ed25519 signature against raw bytes and a public key.
  static Future<bool> verifySignature({
    required Uint8List bytes,
    required Uint8List signatureBytes,
    required SimplePublicKey publicKey,
  }) async {
    final sig = Signature(
      signatureBytes,
      publicKey: publicKey,
    );
    return await _ed25519.verify(bytes, signature: sig);
  }

  /// Encrypts direct message [plaintextPayload] to a recipient's [recipientX25519PublicKey]
  /// using X25519 ECDH key agreement + ChaCha20-Poly1305.
  /// Output format: 12-byte Nonce + CipherText + 16-byte MAC Tag
  static Future<Uint8List> encryptDirectMessage({
    required Uint8List plaintextPayload,
    required SimpleKeyPair senderX25519KeyPair,
    required SimplePublicKey recipientX25519PublicKey,
  }) async {
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: senderX25519KeyPair,
      remotePublicKey: recipientX25519PublicKey,
    );

    final secretBox = await _cipher.encrypt(
      plaintextPayload,
      secretKey: sharedSecret,
    );

    final builder = BytesBuilder();
    builder.add(secretBox.nonce);
    builder.add(secretBox.cipherText);
    builder.add(secretBox.mac.bytes);
    return builder.toBytes();
  }

  /// Decrypts a direct message payload encrypted with [encryptDirectMessage].
  static Future<Uint8List> decryptDirectMessage({
    required Uint8List encryptedPayload,
    required SimpleKeyPair recipientX25519KeyPair,
    required SimplePublicKey senderX25519PublicKey,
  }) async {
    if (encryptedPayload.length < 12 + 16) {
      throw const FormatException('Encrypted payload too short');
    }

    final nonce = encryptedPayload.sublist(0, 12);
    final macBytes = encryptedPayload.sublist(encryptedPayload.length - 16);
    final cipherText = encryptedPayload.sublist(12, encryptedPayload.length - 16);

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: recipientX25519KeyPair,
      remotePublicKey: senderX25519PublicKey,
    );

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final cleartext = await _cipher.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );

    return Uint8List.fromList(cleartext);
  }
}
