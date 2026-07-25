import 'dart:convert';
import 'dart:typed_data';

/// A known peer/contact in the mesh network.
class Peer {
  final String deviceId;
  final String publicKeyBase64; // Ed25519 public key, base64-encoded
  final String? encryptionKeyBase64; // X25519 public key, base64-encoded
  final String? nickname;
  final int? lastSeen; // epoch millis

  const Peer({
    required this.deviceId,
    required this.publicKeyBase64,
    this.encryptionKeyBase64,
    this.nickname,
    this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'publicKey': publicKeyBase64,
      'encryptionKey': encryptionKeyBase64,
      'nickname': nickname,
      'lastSeen': lastSeen,
    };
  }

  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      deviceId: map['deviceId'] as String,
      publicKeyBase64: map['publicKey'] as String,
      encryptionKeyBase64: map['encryptionKey'] as String?,
      nickname: map['nickname'] as String?,
      lastSeen: map['lastSeen'] as int?,
    );
  }

  Peer copyWith({
    String? nickname,
    int? lastSeen,
    String? encryptionKeyBase64,
  }) {
    return Peer(
      deviceId: deviceId,
      publicKeyBase64: publicKeyBase64,
      encryptionKeyBase64: encryptionKeyBase64 ?? this.encryptionKeyBase64,
      nickname: nickname ?? this.nickname,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Decode public key bytes from base64.
  Uint8List get publicKeyBytes => base64Decode(publicKeyBase64);

  /// Decode encryption key bytes from base64 (if present).
  Uint8List? get encryptionKeyBytes =>
      encryptionKeyBase64 != null ? base64Decode(encryptionKeyBase64!) : null;

  @override
  String toString() {
    return 'Peer(id: $deviceId, nick: $nickname, lastSeen: $lastSeen)';
  }
}
