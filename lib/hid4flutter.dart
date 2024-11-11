export 'src/hid_device.dart';
export 'src/hid_exception.dart';

import 'src/hid_device.dart';
import 'src/hid_platform_interface.dart';
export 'src/android/hid_android.dart';
export 'src/desktop/hid_desktop.dart';

class Hid {
  /// Get a list of connected HID devices that match the
  /// filters passed in. If no filter is provided get all
  /// connected devices.
  ///
  /// Example usage:
  /// ```dart
  /// // List of connected devices with vendorId 0x25 and productId 0x26
  /// List<HidDevice> devices = await getDevices(vendorId: 0x25, productId: 0x26);
  /// ```
  static Future<List<HidDevice>> getDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
  }) {
    return HidPlatform.instance.getDevices(
      vendorId: vendorId,
      productId: productId,
      usagePage: usagePage,
      usage: usage,
    );
  }

  /// Get a stream that emits a list of connected HID devices that match
  /// the filters passed in whenever a device is connected or disconnected.
  /// If no filter is provided the stream will emit all connected devices.
  ///
  /// The stream will emit the initial list of devices immediately after
  /// the stream is listened to. After that, it will emit a new list of
  /// devices whenever a device is connected or disconnected.
  ///
  /// Connection detection is done by he platform by scanning for new devices
  /// at a fixed interval specified by the [pollingInterval] parameter.
  /// The default interval is 1 second.
  ///
  /// On platforms where the native library support listening for device
  /// connection and disconnection events, the polling interval is ignored.
  ///
  /// Example usage:
  /// ```dart
  /// // Stream of connected devices with vendorId 0x25 and productId 0x26
  /// Stream<List<HidDevice>> devices = watchDevices(vendorId: 0x25, productId: 0x26);
  /// ```
  static Stream<List<HidDevice>> watchDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
    Duration pollingInterval = const Duration(seconds: 1),
  }) {
    return HidPlatform.instance.watchDevices(
      vendorId: vendorId,
      productId: productId,
      usagePage: usagePage,
      usage: usage,
      pollingInterval: pollingInterval,
    );
  }
}
