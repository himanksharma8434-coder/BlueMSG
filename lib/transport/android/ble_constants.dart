/// BLE service and characteristic UUIDs for the bitmsg mesh protocol.
class BleConstants {
  BleConstants._();

  /// Custom service UUID identifying this app's mesh protocol.
  /// Generated via uuidgenerator.net — unique to bitmsg.
  static const String serviceUuid = 'b1tm-5g00-4d65-7368-4e6574776f72';

  /// Writable characteristic: other devices write message chunks here.
  static const String writeCharUuid = 'b1tm-5g01-4d65-7368-4e6574776f72';

  /// Notify characteristic: this device pushes outgoing data through notifications.
  static const String notifyCharUuid = 'b1tm-5g02-4d65-7368-4e6574776f72';

  /// The short name advertised over BLE.
  static const String advertisingName = 'bitmsg';
}
