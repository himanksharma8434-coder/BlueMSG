import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

/// Represents a device's cryptographic identity (Ed25519 signing keypair + X25519 keypair).
class MeshIdentity {
  final SimpleKeyPair ed25519KeyPair;
  final SimpleKeyPair x25519KeyPair;
  final SimplePublicKey ed25519PublicKey;
  final SimplePublicKey x25519PublicKey;
  final String deviceId;

  MeshIdentity._({
    required this.ed25519KeyPair,
    required this.x25519KeyPair,
    required this.ed25519PublicKey,
    required this.x25519PublicKey,
    required this.deviceId,
  });

  /// Generates a new random cryptographic identity.
  static Future<MeshIdentity> generate() async {
    final ed25519 = Ed25519();
    final x25519 = X25519();

    final edKeyPair = await ed25519.newKeyPair();
    final xKeyPair = await x25519.newKeyPair();

    final edPub = await edKeyPair.extractPublicKey();
    final xPub = await xKeyPair.extractPublicKey();

    final deviceId = deriveDeviceId(Uint8List.fromList(edPub.bytes));

    return MeshIdentity._(
      ed25519KeyPair: edKeyPair,
      x25519KeyPair: xKeyPair,
      ed25519PublicKey: edPub,
      x25519PublicKey: xPub,
      deviceId: deviceId,
    );
  }

  /// Recreates a MeshIdentity from raw private key bytes.
  static Future<MeshIdentity> fromPrivateKeyBytes({
    required Uint8List ed25519PrivateBytes,
    required Uint8List x25519PrivateBytes,
  }) async {
    final ed25519 = Ed25519();
    final x25519 = X25519();

    final edKeyPair = await ed25519.newKeyPairFromSeed(ed25519PrivateBytes);
    final xKeyPair = await x25519.newKeyPairFromSeed(x25519PrivateBytes);

    final edPub = await edKeyPair.extractPublicKey();
    final xPub = await xKeyPair.extractPublicKey();

    final deviceId = deriveDeviceId(Uint8List.fromList(edPub.bytes));

    return MeshIdentity._(
      ed25519KeyPair: edKeyPair,
      x25519KeyPair: xKeyPair,
      ed25519PublicKey: edPub,
      x25519PublicKey: xPub,
      deviceId: deviceId,
    );
  }

  /// Derives a short, human-readable device ID from the Ed25519 public key bytes.
  /// First 16 hex characters of SHA-256(publicKey).
  static String deriveDeviceId(Uint8List ed25519PublicKeyBytes) {
    final digest = crypto.sha256.convert(ed25519PublicKeyBytes);
    return digest.toString().substring(0, 16);
  }

  /// Extracts raw seed/private key bytes for ed25519.
  Future<Uint8List> getEd25519PrivateBytes() async {
    final bytes = await ed25519KeyPair.extractPrivateKeyBytes();
    return Uint8List.fromList(bytes);
  }

  /// Extracts raw seed/private key bytes for x25519.
  Future<Uint8List> getX25519PrivateBytes() async {
    final bytes = await x25519KeyPair.extractPrivateKeyBytes();
    return Uint8List.fromList(bytes);
  }

  @override
  String toString() => 'MeshIdentity(deviceId: $deviceId)';
}
