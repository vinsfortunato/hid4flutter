import 'package:hid4flutter/src/hid_device.dart';
import 'package:hid4flutter/src/hid_platform_interface.dart';

class HidAndroid extends HidPlatform {
  static registerWith() {
    HidPlatform.instance = HidAndroid();
  }

  @override
  Future<List<HidDevice>> getDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
  }) {
    // TODO: implement getDevices
    throw UnimplementedError();
  }

  @override
  Stream<List<HidDevice>> watchDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
    required Duration pollingInterval,
  }) {
    // TODO: implement watchDevices
    throw UnimplementedError();
  }
}
