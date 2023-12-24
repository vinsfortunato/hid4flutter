import 'package:flutter_test/flutter_test.dart';
import 'package:hid4flutter/hid4flutter.dart';
import 'package:hid4flutter/hid4flutter_platform_interface.dart';
import 'package:hid4flutter/hid4flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHid4flutterPlatform
    with MockPlatformInterfaceMixin
    implements Hid4flutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final Hid4flutterPlatform initialPlatform = Hid4flutterPlatform.instance;

  test('$MethodChannelHid4flutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHid4flutter>());
  });

  test('getPlatformVersion', () async {
    Hid4flutter hid4flutterPlugin = Hid4flutter();
    MockHid4flutterPlatform fakePlatform = MockHid4flutterPlatform();
    Hid4flutterPlatform.instance = fakePlatform;

    expect(await hid4flutterPlugin.getPlatformVersion(), '42');
  });
}
