import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hid4flutter/src/hid_device.dart';
import 'package:hid4flutter/src/hid_exception.dart';
import 'package:hid4flutter/src/android/hid_android.dart';

class HidDeviceAndroid extends HidDevice {
  static const Duration _inputPollTimeout = Duration(milliseconds: 250);
  static const int _defaultInputChunkSize = 1024;

  HidDeviceAndroid({
    required this.id,
    required this.path,
    required this.vendorId,
    required this.productId,
    required this.serialNumber,
    required this.releaseNumber,
    required this.manufacturer,
    required this.productName,
    required this.usagePage,
    required this.usage,
    required this.interfaceNumber,
    required this.busType,
  });

  factory HidDeviceAndroid.fromMap(Map<dynamic, dynamic> map) {
    return HidDeviceAndroid(
      id: map['id']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      vendorId: (map['vendorId'] ?? 0) as int,
      productId: (map['productId'] ?? 0) as int,
      serialNumber: map['serialNumber']?.toString() ?? '',
      releaseNumber: (map['releaseNumber'] ?? 0) as int,
      manufacturer: map['manufacturer']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      usagePage: (map['usagePage'] ?? 0) as int,
      usage: (map['usage'] ?? 0) as int,
      interfaceNumber: (map['interfaceNumber'] ?? 0) as int,
      busType: (map['busType'] ?? 0) as int,
    );
  }

  @override
  final String id;
  @override
  final String path;
  @override
  final int vendorId;
  @override
  final int productId;
  @override
  final String serialNumber;
  @override
  final int releaseNumber;
  @override
  final String manufacturer;
  @override
  final String productName;
  @override
  final int usagePage;
  @override
  final int usage;
  @override
  final int interfaceNumber;
  @override
  final int busType;

  bool _isOpen = false;

  @override
  Future<void> open() async {
    if (_isOpen) {
      throw StateError('Device is already open');
    }

    try {
      await HidAndroid.invokeMethod('openDevice', {
        'id': id,
        'path': path,
        'interfaceNumber': interfaceNumber,
      });
      _isOpen = true;
    } on PlatformException catch (e) {
      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'Failed to open HID device';
      throw HidException('${e.code}: $message');
    }
  }

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }
    try {
      await HidAndroid.invokeMethod('closeDevice', {
        'id': id,
        'path': path,
        'interfaceNumber': interfaceNumber,
      });
      _isOpen = false;
    } on PlatformException catch (e) {
      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'Failed to close HID device';
      throw HidException('${e.code}: $message');
    }
  }

  @override
  Stream<int> inputStream() {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }

    return (() async* {
      while (_isOpen) {
        try {
          final report = await _readReportChunk(
            _defaultInputChunkSize,
            timeout: _inputPollTimeout,
          );

          for (final byte in report) {
            yield byte;
          }
        } on TimeoutException {
          continue;
        } on HidException {
          if (!_isOpen) {
            break;
          }
          rethrow;
        }
      }
    })();
  }

  @override
  Future<Uint8List> receiveReport(int reportLength, {Duration? timeout}) async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }

    var result = inputStream().take(reportLength).toList();
    if (timeout != null) {
      result = result.timeout(timeout);
    }

    return Uint8List.fromList(await result);
  }

  @override
  Future<void> sendReport(Uint8List data, {int reportId = 0x00}) async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }
    try {
      await HidAndroid.invokeMethod('sendReport', {
        'id': id,
        'path': path,
        'interfaceNumber': interfaceNumber,
        'reportId': reportId,
        'data': data,
      });
    } on PlatformException catch (e) {
      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'Failed to send HID report';
      throw HidException('${e.code}: $message');
    }
  }

  @override
  Future<Uint8List> receiveFeatureReport(int reportId,
      {int bufferSize = 1024}) async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }

    try {
      return await HidAndroid.invokeMethod<Uint8List>('receiveFeatureReport', {
            'id': id,
            'path': path,
            'interfaceNumber': interfaceNumber,
            'reportId': reportId,
            'bufferSize': bufferSize,
          }) ??
          Uint8List(0);
    } on PlatformException catch (e) {
      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'Failed to receive feature report';
      throw HidException('${e.code}: $message');
    }
  }

  @override
  Future<void> sendFeatureReport(Uint8List data, {int reportId = 0x00}) async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }

    try {
      await HidAndroid.invokeMethod('sendFeatureReport', {
        'id': id,
        'path': path,
        'interfaceNumber': interfaceNumber,
        'reportId': reportId,
        'data': data,
      });
    } on PlatformException catch (e) {
      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'Failed to send feature report';
      throw HidException('${e.code}: $message');
    }
  }

  @override
  Future<String> getIndexedString(int index, {int maxLength = 256}) async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }

    try {
      return await HidAndroid.invokeMethod<String>('getIndexedString', {
            'id': id,
            'path': path,
            'interfaceNumber': interfaceNumber,
            'index': index,
            'maxLength': maxLength,
          }) ??
          '';
    } on PlatformException catch (e) {
      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'Failed to get indexed string';
      throw HidException('${e.code}: $message');
    }
  }

  Future<Uint8List> _readReportChunk(
    int reportLength, {
    Duration? timeout,
  }) async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }

    try {
      return await HidAndroid.invokeMethod<Uint8List>('receiveReport', {
            'id': id,
            'path': path,
            'interfaceNumber': interfaceNumber,
            'reportLength': reportLength,
            'timeoutMs': timeout?.inMilliseconds,
          }) ??
          Uint8List(0);
    } on PlatformException catch (e) {
      if (e.code == 'TIMEOUT') {
        throw TimeoutException(
          e.message ?? 'Timed out waiting for input report',
          timeout,
        );
      }

      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'Failed to receive HID report';
      throw HidException('${e.code}: $message');
    }
  }
}
