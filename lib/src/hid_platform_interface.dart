import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:hid4flutter/src/hid_device.dart';

abstract class HidPlatform extends PlatformInterface {
  HidPlatform() : super(token: _token);

  static final Object _token = Object();

  static late HidPlatform _instance;

  /// The default instance of [HidPlatform] to use.
  ///
  /// Defaults to [HidPlatform].
  static HidPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HidPlatform] when
  /// they register themselves.
  static set instance(HidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> init();

  Future<void> exit();

  Future<List<HidDevice>> getDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
  });
}
