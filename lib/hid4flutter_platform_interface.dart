import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hid4flutter_method_channel.dart';

abstract class Hid4flutterPlatform extends PlatformInterface {
  /// Constructs a Hid4flutterPlatform.
  Hid4flutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static Hid4flutterPlatform _instance = MethodChannelHid4flutter();

  /// The default instance of [Hid4flutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelHid4flutter].
  static Hid4flutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [Hid4flutterPlatform] when
  /// they register themselves.
  static set instance(Hid4flutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
