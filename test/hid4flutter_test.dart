import 'package:flutter_test/flutter_test.dart';
import 'package:hid4flutter/hid4flutter.dart';
import 'package:hid4flutter/hid4flutter_platform_interface.dart';
import 'package:hid4flutter/hid4flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHid4FlutterPlatform
    with MockPlatformInterfaceMixin
    implements Hid4FlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final Hid4FlutterPlatform initialPlatform = Hid4FlutterPlatform.instance;

  test('$MethodChannelHid4Flutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHid4Flutter>());
  });

  test('getPlatformVersion', () async {
    Hid4Flutter hid4flutterPlugin = Hid4Flutter();
    MockHid4FlutterPlatform fakePlatform = MockHid4FlutterPlatform();
    Hid4FlutterPlatform.instance = fakePlatform;

    expect(await hid4flutterPlugin.getPlatformVersion(), '42');
  });
}
