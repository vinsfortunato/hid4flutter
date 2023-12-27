import 'package:hid4flutter/src/hid_device.dart';
import 'package:hid4flutter/src/hid_platform_interface.dart';

class HidAndroid extends HidPlatform {
  static registerWith() {
    HidPlatform.instance = HidAndroid();
  }

  @override
  Future<void> exit() {
    // TODO: implement exit
    throw UnimplementedError();
  }

  @override
  Future<void> init() {
    // TODO: implement init
    throw UnimplementedError();
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
}
