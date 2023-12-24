import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hid4flutter_method_channel.dart';

abstract class Hid4FlutterPlatform extends PlatformInterface {
  /// Constructs a Hid4FlutterPlatform.
  Hid4FlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static Hid4FlutterPlatform _instance = MethodChannelHid4Flutter();

  /// The default instance of [Hid4FlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelHid4Flutter].
  static Hid4FlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [Hid4FlutterPlatform] when
  /// they register themselves.
  static set instance(Hid4FlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
