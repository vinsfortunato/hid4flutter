export 'src/hid_device.dart';
export 'src/hid_exception.dart';

import 'src/hid_device.dart';
import 'src/hid_platform_interface.dart';
export 'src/android/hid_android.dart';
export 'src/desktop/hid_desktop.dart';

class Hid {
  Future<void> init() {
    return HidPlatform.instance.init();
  }

  Future<void> exit() {
    return HidPlatform.instance.exit();
  }

  Future<List<HidDevice>> getAttachedDevices() {
    return HidPlatform.instance.getAttachedDevices();
  }
}
