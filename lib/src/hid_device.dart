import 'dart:typed_data';
import 'hid_exception.dart';

/// Represents an HID device. Provides properties for accessing information
/// about the device, methods for opening and closing the connection, and
/// the sending and receiving of reports.
///
/// Example usage:
/// ```dart
/// final HidDevice device = ...
///
/// await device.open();
///
/// // Send an Output report of 32 bytes (all zeroes).
/// // The reportId is optional (default is 0x00).
/// // It will be prefixed to the data as per HID rules.
/// Uint8List data = Uint8List(32);
/// await device.sendReport(reportId: 0x00, reportData);
///
/// // Close when no more needed
/// await device.close();
/// ```
abstract class HidDevice {
  /// Get the HidDevice unique id.
  String get id;

  /// Get the platform-specific device path.
  String get path;

  /// Get the device vendor ID.
  int get vendorId;

  /// Get the device product ID.
  int get productId;

  /// Get the device serial number.
  String get serialNumber;

  /// Get the device release number in binary-coded decimal,
  /// also known as Device Version Number.
  int get releaseNumber;

  /// Get the manufacturer String.
  String get manufacturer;

  /// Get the product name String.
  String get productName;

  /// Get the usage page for this Device/Interface.
  int get usagePage;

  /// Get the usage for this Device/Interface.
  int get usage;

  /// The USB interface which this logical device represents.
  int get interfaceNumber;

  /// Get the underlying bus type.
  int get busType;

  /// Open a HID device.
  ///
  /// Must be closed by calling [close] when no more needed.
  ///
  /// Throws an [StateError] if the device is already open.
  /// Throws an [HidException] if the attempt to open the device fails.
  Future<void> open();

  /// Check if the HID device is open.
  bool get isOpen;

  /// Close the HID device.
  ///
  /// Must be called when an open device is no more needed.
  ///
  /// Throws an [StateError] if the device is not open.
  /// Throws an [HidException] if the attempt to close the device fails.
  Future<void> close();

  /// Get the Input report stream.
  Stream<int> inputStream();

  /// Receive an Input report from the HID device.
  ///
  /// An optional [timeout] can be passed for setting
  /// the duration to wait before giving up.
  ///
  /// Throws an [StateError] if the device is not open.
  /// Throws an [TimeoutException] if the attempt to receive the report time out.
  /// Throws an [HidException] if the attempt to receive the report fails.
  Future<Uint8List> receiveReport(int reportLength, {Duration? timeout});

  /// Send an Output report to the HID device.
  ///
  /// The [reportId] will be prefixed to the HID packet as per HID rules.
  ///
  /// Throws an [StateError] if the device is not open.
  /// Throws an [HidException] if the attempt to send the report fails.
  Future<void> sendReport(Uint8List data, {int reportId = 0x00});

  /// Get a feature report from the HID device.
  ///
  /// Throws an [StateError] if the device is not open.
  /// Throws an [HidException] if the attempt to get the report fails.
  Future<Uint8List> receiveFeatureReport(
    int reportId, {
    int bufferSize = 1024,
  });

  /// Send a Feature report to the HID device.
  ///
  /// The [reportId] will be prefixed to the HID packet as per HID rules.
  ///
  /// Throws an [StateError] if the device is not open.
  /// Throws an [HidException] if the attempt to send the report fails.
  Future<void> sendFeatureReport(Uint8List data, {int reportId = 0x00});

  /// Get a string from an HID device, based on its string index.
  ///
  /// Throws an [StateError] if the device is not open.
  /// Throws an [HidException] if the attempt to get the string fails.
  Future<String> getIndexedString(int index, {int maxLength = 256});

  @override
  bool operator ==(covariant HidDevice other) {
    if (identical(this, other)) return true;

    return other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }

  @override
  String toString() {
    return '''
      HidDevice [
        id=$path,
        path=$path, 
        vendorId=0x${vendorId.toRadixString(16)}, 
        productId=0x${productId.toRadixString(16)},
        serialNumber=$serialNumber, 
        releaseNumber=0x${releaseNumber.toRadixString(16)}, 
        manufacturer=$manufacturer, 
        productName=$productName, 
        usagePage=0x${usagePage.toRadixString(16)}, 
        usage=0x${usage.toRadixString(16)}, 
        interfaceNumber=$interfaceNumber
      ]''';
  }
}
