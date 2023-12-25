import 'dart:typed_data';

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

  /// Get the product String.
  String get product;

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
  Future<void> open();

  /// Check if the HID device is open.
  bool get isOpen;

  /// Close the HID device.
  ///
  /// Must be called when an open device is no more needed.
  Future<void> close();

  /// Read an Input report from a HID device.
  ///
  /// An optional [timeout] can be passed for setting
  /// the duration to wait before giving up.
  Future<Uint8List> read(int amountToRead, {Duration? timeout});

  /// Write an Output report to a HID device.
  ///
  /// The [reportId] will be prefixed to the HID packet as per HID rules.
  ///
  /// Returns the actual number of bytes written.
  Future<int> write(Uint8List data, {int reportId = 0x00});

  /// Get a feature report from a HID device.
  Future<Uint8List> getFeatureReport(int reportId, {int bufferLength = 1024});

  /// Send a Feature report to the device.
  ///
  /// The [reportId] will be prefixed to the HID packet as per HID rules.
  ///
  /// Returns the actual number of bytes written.
  Future<int> sendFeatureReport(Uint8List data, {int reportId = 0x00});

  /// Get a string from an HID device, based on its string index.
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
        product=$product, 
        usagePage=0x${usagePage.toRadixString(16)}, 
        usage=0x${usage.toRadixString(16)}, 
        interfaceNumber=$interfaceNumber
      ]''';
  }
}
