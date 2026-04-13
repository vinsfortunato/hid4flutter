import 'package:flutter/services.dart';
import 'package:hid4flutter/src/hid_device.dart';
import 'package:hid4flutter/src/hid_platform_interface.dart';
import 'package:hid4flutter/src/android/hid_device_android.dart';

class HidAndroid extends HidPlatform {
  static registerWith() {
    HidPlatform.instance = HidAndroid();
  }

  static const MethodChannel _channel = MethodChannel('hid4flutter');

  // Expose a safe static helper to invoke platform methods from other classes
  static Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  @override
  Future<List<HidDevice>> getDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
  }) async {
    final args = <String, Object?>{
      if (vendorId != null) 'vendorId': vendorId,
      if (productId != null) 'productId': productId,
      if (usagePage != null) 'usagePage': usagePage,
      if (usage != null) 'usage': usage,
    };

    final List<dynamic> result =
        await _channel.invokeMethod('getDevices', args);

    return result
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => HidDeviceAndroid.fromMap(m))
        .toList(growable: false);
  }
}
