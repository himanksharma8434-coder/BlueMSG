import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Utility class for handling BLE permission flows on Android.
class BlePermissionHandler {
  /// Check if Bluetooth adapter is available and turned on.
  static Future<bool> isBluetoothAvailable() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  /// Check if Android Location Services (GPS toggle) is enabled.
  static Future<bool> isLocationServiceEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.location.serviceStatus;
      return status.isEnabled;
    } catch (_) {
      return true;
    }
  }

  /// Request the user to turn on Bluetooth.
  static Future<void> requestBluetoothOn() async {
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
  }

  /// Request all required Android BLE permissions.
  /// Returns true if all required permissions are granted.
  static Future<bool> requestAllPermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // Check if all permissions are granted
    final allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );

    return allGranted;
  }

  /// Check if all required BLE permissions are already granted.
  static Future<bool> arePermissionsGranted() async {
    if (!Platform.isAndroid) return true;

    final results = await Future.wait([
      Permission.bluetoothScan.isGranted,
      Permission.bluetoothAdvertise.isGranted,
      Permission.bluetoothConnect.isGranted,
      Permission.locationWhenInUse.isGranted,
    ]);

    return results.every((granted) => granted);
  }

  /// Check which specific permissions are missing.
  static Future<List<String>> getMissingPermissions() async {
    if (!Platform.isAndroid) return [];

    final missing = <String>[];

    if (!await Permission.bluetoothScan.isGranted) {
      missing.add('Bluetooth Scan');
    }
    if (!await Permission.bluetoothAdvertise.isGranted) {
      missing.add('Bluetooth Advertise');
    }
    if (!await Permission.bluetoothConnect.isGranted) {
      missing.add('Bluetooth Connect');
    }
    if (!await Permission.locationWhenInUse.isGranted) {
      missing.add('Location');
    }

    return missing;
  }

  /// Open app settings for the user to manually grant permissions.
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
