/// BLE service and characteristic UUIDs for the bitmsg mesh protocol.
class BleConstants {
  BleConstants._();

  /// Custom service UUID identifying this app's mesh protocol.
  /// Generated via uuidgenerator.net — unique to bitmsg.
  static const String serviceUuid = '6269746d-7367-4000-8000-000000000001';

  /// Writable characteristic: other devices write message chunks here.
  static const String writeCharUuid = '6269746d-7367-4000-8000-000000000002';

  /// Notify characteristic: this device pushes outgoing data through notifications.
  static const String notifyCharUuid = '6269746d-7367-4000-8000-000000000003';

  /// The short name advertised over BLE.
  static const String advertisingName = 'bitmsg';
}
