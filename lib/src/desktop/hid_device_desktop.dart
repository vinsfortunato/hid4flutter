import 'dart:async';
import 'dart:typed_data';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'package:hid4flutter/src/hid_device.dart';
import 'package:hid4flutter/src/hid_exception.dart';
import 'package:hid4flutter/src/desktop/extensions.dart';
import 'package:hid4flutter/src/desktop/hidapi_ffi.dart';

class HidDeviceDesktop extends HidDevice {
  final String _path;
  final int _vendorId;
  final int _productId;
  final String _serialNumber;
  final int _releaseNumber;
  final String _manufacturer;
  final String _productName;
  final int _usagePage;
  final int _usage;
  final int _interfaceNumber;
  final int _busType;

  final NativeLibrary _hidapi;
  Pointer<hid_device_> _device = nullptr;

  final List<void Function()> _onOpenCallbacks = [];
  final List<void Function()> _onCloseCallbacks = [];

  HidDeviceDesktop({
    required NativeLibrary hidapi,
    required hid_device_info info,
  })  : _hidapi = hidapi,
        _path = info.path.toDartString(),
        _vendorId = info.vendor_id,
        _productId = info.product_id,
        _serialNumber = info.serial_number.toDartString(),
        _releaseNumber = info.release_number,
        _manufacturer = info.manufacturer_string.toDartString(),
        _productName = info.product_string.toDartString(),
        _usagePage = info.usage_page,
        _usage = info.usage,
        _interfaceNumber = info.interface_number,
        _busType = info.bus_type;

  @override
  String get id => _path;

  @override
  String get path => _path;

  @override
  int get vendorId => _vendorId;

  @override
  int get productId => _productId;

  @override
  String get serialNumber => _serialNumber;

  @override
  int get releaseNumber => _releaseNumber;

  @override
  String get manufacturer => _manufacturer;

  @override
  String get productName => _productName;

  @override
  int get usagePage => _usagePage;

  @override
  int get usage => _usage;

  @override
  int get interfaceNumber => _interfaceNumber;

  @override
  int get busType => _busType;

  @override
  Future<void> open() async {
    if (isOpen) {
      throw StateError('Device is already open.');
    }

    using((Arena arena) {
      _device = _hidapi.hid_open_path(path.toCharPointer(allocator: arena));

      if (_device == nullptr) {
        throw HidException('Failed to open hid device. '
            'Error: $_getLastErrorMessage()');
      }

      // Enable non blocking mode
      if (_hidapi.hid_set_nonblocking(_device, 1) == -1) {
        throw HidException('Failed to set non blocking mode. '
            'Error: $_getLastErrorMessage()');
      }

      // Notify listeners
      for (var callback in _onOpenCallbacks) {
        callback.call();
      }

      return;
    });
  }

  @override
  bool get isOpen => _device != nullptr;

  void onOpen(void Function() onOpenCallback) {
    _onOpenCallbacks.add(onOpenCallback);
  }

  @override
  Future<void> close() async {
    if (!isOpen) {
      throw StateError('Device is not open.');
    }

    _hidapi.hid_close(_device);
    _device = nullptr;

    // Notify listeners
    for (var callback in _onCloseCallbacks) {
      callback.call();
    }
  }

  void onClose(void Function() onCloseCallback) {
    _onCloseCallbacks.add(onCloseCallback);
  }

  @override
  Future<Uint8List> receiveReport(int amountToRead, {Duration? timeout}) {
    if (!isOpen) {
      throw StateError('Device is not open.');
    }

    return using((Arena arena) async {
      var buffer = arena<Uint8>(amountToRead);

      // Call hid_read() every 100 microseconds until it
      // returns some data or the timeout expires.
      //
      // If the timeout is not specified return an empty list
      // when the first call to hid_read() returns no data.
      final timeoutCompleter = Completer();
      Future.delayed(timeout ?? Duration.zero).then(timeoutCompleter.complete);

      int result;

      //TODO collect data until amountToRead bytes have been received.

      do {
        result = _hidapi.hid_read(
            _device, buffer.cast<UnsignedChar>(), amountToRead);

        await Future.delayed(Duration(microseconds: 100));
      } while (result == 0 && !timeoutCompleter.isCompleted);

      if (result == 0) {
        if (timeout != null) {
          throw TimeoutException('Read timed out.');
        } else {
          return Uint8List(0);
        }
      } else if (result == -1) {
        throw HidException('Failed to read $amountToRead bytes. '
            'Error: $_getLastErrorMessage()');
      } else {
        return Uint8List.fromList(buffer.asTypedList(result));
      }
    });
  }

  @override
  Future<int> sendReport(Uint8List data, {int reportId = 0x00}) async {
    if (!isOpen) {
      throw StateError('Device is not open.');
    }

    int bufferLength = data.length + 1;

    return using((Arena arena) {
      var buffer = arena<Uint8>(bufferLength);
      buffer[0] = reportId;
      buffer.asTypedList(bufferLength).setAll(1, data);
      int result =
          _hidapi.hid_write(_device, buffer.cast<UnsignedChar>(), bufferLength);

      if (result == -1) {
        throw HidException('Failed to write $bufferLength bytes. '
            'Error: $_getLastErrorMessage()');
      } else {
        return result;
      }
    });
  }

  @override
  Future<Uint8List> getFeatureReport(int reportId,
      {int bufferLength = 1024}) async {
    return using((Arena arena) {
      var buffer = arena<Uint8>(bufferLength);
      buffer[0] = reportId;
      buffer.asTypedList(bufferLength).fillRange(1, bufferLength, 0);
      int result = _hidapi.hid_get_feature_report(
          _device, buffer.cast<UnsignedChar>(), bufferLength);

      if (result == -1) {
        throw HidException('Failed to read feature report. '
            'Error: $_getLastErrorMessage()');
      } else if (result == 0) {
        return Uint8List(0);
      } else {
        return Uint8List.fromList(buffer.asTypedList(result));
      }
    });
  }

  @override
  Future<void> sendFeatureReport(Uint8List data, {int reportId = 0x00}) async {
    if (!isOpen) {
      throw StateError('Device is not open.');
    }

    int bufferLength = data.length + 1;

    using((Arena arena) {
      var buffer = arena<Uint8>(bufferLength);
      buffer[0] = reportId;
      buffer.asTypedList(bufferLength).setAll(1, data);
      int result = _hidapi.hid_send_feature_report(
          _device, buffer.cast<UnsignedChar>(), bufferLength);
      if (result == -1) {
        throw HidException(
            'Failed to send feature report of $bufferLength bytes. '
            'Error: $_getLastErrorMessage()');
      } else {
        return result;
      }
    });
  }

  @override
  Future<String> getIndexedString(int index, {int maxLength = 256}) async {
    if (!isOpen) {
      throw StateError('Device is not open.');
    }

    return using((Arena arena) {
      var buffer = arena<WChar>(maxLength);
      int result =
          _hidapi.hid_get_indexed_string(_device, index, buffer, maxLength);

      if (result == 0) {
        return buffer.toDartString();
      } else {
        throw HidException('Failed to get indexed string with $index index. '
            'Error: $_getLastErrorMessage()');
      }
    });
  }

  String _getLastErrorMessage() {
    return _hidapi.hid_error(_device).toDartString();
  }
}
