export 'src/hid_device.dart';
export 'src/hid_exception.dart';

import 'src/hid_device.dart';
import 'src/hid_platform_interface.dart';
export 'src/android/hid_android.dart';
export 'src/desktop/hid_desktop.dart';

class Hid {
  static Future<void> init() {
    return HidPlatform.instance.init();
  }

  static Future<void> exit() {
    return HidPlatform.instance.exit();
  }

  /// Get a list of connected HID devices that match the
  /// filters passed in. If no filter is provided get all
  /// connected devices.
  ///
  /// Example usage:
  /// ```dart
  /// List<HidDevice> devices = await getDevices(vendorId: 0x25, productId: 0x26);
  /// ```
  static Future<List<HidDevice>> getDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
  }) {
    return HidPlatform.instance.getDevices();
  }
}
