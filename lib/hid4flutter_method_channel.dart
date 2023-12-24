import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hid4flutter_platform_interface.dart';

/// An implementation of [Hid4flutterPlatform] that uses method channels.
class MethodChannelHid4flutter extends Hid4flutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hid4flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
