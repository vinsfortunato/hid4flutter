import 'package:flutter_test/flutter_test.dart';
import 'package:hid4flutter/hid4flutter.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHidPlatform with MockPlatformInterfaceMixin implements HidPlatform {
  @override
  Future<void> exit() {
    throw UnimplementedError();
  }

  @override
  Future<List<HidDevice>> getAttachedDevices() async {
    return List.empty();
  }

  @override
  Future<bool> init() {
    throw UnimplementedError();
  }
}

void main() {
  test('attachedDevices', () async {
    MockHidPlatform fakePlatform = MockHidPlatform();
    HidPlatform.instance = fakePlatform;

    expect(await fakePlatform.getAttachedDevices(), List.empty());
  });
}
