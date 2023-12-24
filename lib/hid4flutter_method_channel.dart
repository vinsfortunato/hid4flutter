import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hid4flutter_platform_interface.dart';

/// An implementation of [Hid4FlutterPlatform] that uses method channels.
class MethodChannelHid4Flutter extends Hid4FlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hid4flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
