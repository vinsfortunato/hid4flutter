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
  Future<List<HidDevice>> getAttachedDevices() {
    // TODO: implement getAttachedDevices
    throw UnimplementedError();
  }

  @override
  Future<void> init() {
    // TODO: implement init
    throw UnimplementedError();
  }
}
