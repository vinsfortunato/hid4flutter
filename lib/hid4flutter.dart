
import 'hid4flutter_platform_interface.dart';

class Hid4flutter {
  Future<String?> getPlatformVersion() {
    return Hid4flutterPlatform.instance.getPlatformVersion();
  }
}
