import 'package:flutter_test/flutter_test.dart';
import 'package:hid4flutter/hid4flutter.dart';
import 'package:hid4flutter/src/hid_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHidPlatform with MockPlatformInterfaceMixin implements HidPlatform {
  @override
  Future<List<HidDevice>> getDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
  }) async {
    return List.empty();
  }
}

void main() async {
  test('devices', () async {
    MockHidPlatform fakePlatform = MockHidPlatform();
    HidPlatform.instance = fakePlatform;

    expect(await fakePlatform.getDevices(), List.empty());
  });
}
