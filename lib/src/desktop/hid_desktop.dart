import 'dart:ffi';

import 'package:hid4flutter/src/hid_device.dart';
import 'package:hid4flutter/src/hid_platform_interface.dart';
import 'package:hid4flutter/src/hid_exception.dart';
import 'package:hid4flutter/src/desktop/hidapi_ffi.dart';
import 'package:hid4flutter/src/desktop/hid_device_desktop.dart';

class HidWindows extends _HidDesktop {
  HidWindows(super.hidapi);

  static registerWith() {
    final hidapi = NativeLibrary(DynamicLibrary.open('hidapi.dll'));
    HidPlatform.instance = HidWindows(hidapi);
  }
}

class HidMacos extends _HidDesktop {
  HidMacos(super.hidapi);

  static registerWith() {
    final hidapi = NativeLibrary(DynamicLibrary.executable());
    HidPlatform.instance = HidMacos(hidapi);
  }
}

class HidLinux extends _HidDesktop {
  HidLinux(super.hidapi);

  static registerWith() {
    final hidapi = NativeLibrary(DynamicLibrary.open('libhidapi-hidraw.so.0'));
    HidPlatform.instance = HidLinux(hidapi);
  }
}

class _HidDesktop extends HidPlatform {
  _HidDesktop(this._hidapi);

  final NativeLibrary _hidapi;

  @override
  Future<void> init() async {
    if (_hidapi.hid_init() == -1) {
      throw HidException('HidApi did not initialise.');
    }
  }

  @override
  Future<void> exit() async {
    if (_hidapi.hid_exit() == -1) {
      throw HidException('HidApi did not exit correctly.');
    }
  }

  @override
  Future<List<HidDevice>> getDevices({
    int? vendorId,
    int? productId,
    int? usagePage,
    int? usage,
  }) async {
    List<HidDevice> devices = [];

    // HidApi hid_enumerate returns a linked list of device info.
    final pointer = _hidapi.hid_enumerate(vendorId ?? 0, productId ?? 0);

    var current = pointer;
    while (current.address != nullptr.address) {
      final info = current.ref;

      if (usagePage != null && usagePage != info.usage_page) {
        // Skip device
        continue;
      }

      if (usage != null && usage != info.usage) {
        // Skip device
        continue;
      }

      devices.add(HidDeviceDesktop(
        hidapi: _hidapi,
        info: info,
      ));
      current = info.next;
    }

    _hidapi.hid_free_enumeration(pointer);
    return devices;
  }
}
