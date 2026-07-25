import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'mesh_identity.dart';

abstract class IdentityStorageInterface {
  Future<MeshIdentity?> loadIdentity();
  Future<void> saveIdentity(MeshIdentity identity);
  Future<void> clearIdentity();
}

/// Secure storage implementation using flutter_secure_storage.
class SecureIdentityStorage implements IdentityStorageInterface {
  static const String _kEd25519Key = 'bitmsg_ed25519_priv';
  static const String _kX25519Key = 'bitmsg_x25519_priv';

  final FlutterSecureStorage _storage;

  SecureIdentityStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<MeshIdentity?> loadIdentity() async {
    final edBase64 = await _storage.read(key: _kEd25519Key);
    final xBase64 = await _storage.read(key: _kX25519Key);

    if (edBase64 == null || xBase64 == null) {
      return null;
    }

    final edBytes = base64Decode(edBase64);
    final xBytes = base64Decode(xBase64);

    return MeshIdentity.fromPrivateKeyBytes(
      ed25519PrivateBytes: edBytes,
      x25519PrivateBytes: xBytes,
    );
  }

  @override
  Future<void> saveIdentity(MeshIdentity identity) async {
    final edBytes = await identity.getEd25519PrivateBytes();
    final xBytes = await identity.getX25519PrivateBytes();

    await _storage.write(key: _kEd25519Key, value: base64Encode(edBytes));
    await _storage.write(key: _kX25519Key, value: base64Encode(xBytes));
  }

  @override
  Future<void> clearIdentity() async {
    await _storage.delete(key: _kEd25519Key);
    await _storage.delete(key: _kX25519Key);
  }
}

/// Mock in-memory storage for unit tests.
class InMemoryIdentityStorage implements IdentityStorageInterface {
  String? _edBase64;
  String? _xBase64;

  @override
  Future<MeshIdentity?> loadIdentity() async {
    if (_edBase64 == null || _xBase64 == null) return null;
    return MeshIdentity.fromPrivateKeyBytes(
      ed25519PrivateBytes: base64Decode(_edBase64!),
      x25519PrivateBytes: base64Decode(_xBase64!),
    );
  }

  @override
  Future<void> saveIdentity(MeshIdentity identity) async {
    _edBase64 = base64Encode(await identity.getEd25519PrivateBytes());
    _xBase64 = base64Encode(await identity.getX25519PrivateBytes());
  }

  @override
  Future<void> clearIdentity() async {
    _edBase64 = null;
    _xBase64 = null;
  }
}
