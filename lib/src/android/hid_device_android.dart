import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hid4flutter/src/hid_device.dart';
import 'package:hid4flutter/src/hid_exception.dart';
import 'package:hid4flutter/src/android/hid_android.dart';

class HidDeviceAndroid extends HidDevice {
  static const EventChannel _eventChannel = EventChannel('hid4flutter/events');

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

  Map<String, Object> get _streamArgs => {
        'path': path,
        'interfaceNumber': interfaceNumber,
      };

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
      throw HidException(
          '${e.code}: ${e.message ?? 'Failed to open HID device'}');
    }
  }

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }
    // Flip the flag first so any concurrent stream consumer can see the device
    // is no longer open and exit promptly without racing the platform call.
    _isOpen = false;
    try {
      await HidAndroid.invokeMethod('closeDevice', {
        'id': id,
        'path': path,
        'interfaceNumber': interfaceNumber,
      });
    } on PlatformException catch (e) {
      throw HidException(
          '${e.code}: ${e.message ?? 'Failed to close HID device'}');
    }
  }

  @override
  Stream<int> inputStream() {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }
    return _eventChannel
        .receiveBroadcastStream(_streamArgs)
        .map<int>((event) => (event as int) & 0xFF)
        .handleError((Object error) {
      if (error is PlatformException) {
        throw HidException('${error.code}: ${error.message ?? 'Stream error'}');
      }
      throw error;
    });
  }

  @override
  Future<Uint8List> receiveReport(int reportLength, {Duration? timeout}) async {
    if (!_isOpen) {
      throw StateError('Device is not open');
    }

    final completer = Completer<Uint8List>();
    final buffer = <int>[];
    late StreamSubscription<int> sub;

    sub = inputStream().listen(
      (byte) {
        buffer.add(byte);
        if (buffer.length >= reportLength) {
          if (!completer.isCompleted) {
            completer.complete(
                Uint8List.fromList(buffer.take(reportLength).toList()));
          }
          sub.cancel();
        }
      },
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) completer.completeError(e, st);
        sub.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
              HidException('Stream closed before report received'));
        }
      },
      cancelOnError: true,
    );

    if (timeout != null) {
      return completer.future.timeout(timeout, onTimeout: () {
        sub.cancel();
        throw TimeoutException('Timed out waiting for input report', timeout);
      });
    }
    return completer.future;
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
      throw HidException(
          '${e.code}: ${e.message ?? 'Failed to send HID report'}');
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
      throw HidException(
          '${e.code}: ${e.message ?? 'Failed to receive feature report'}');
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
      throw HidException(
          '${e.code}: ${e.message ?? 'Failed to send feature report'}');
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
      throw HidException(
          '${e.code}: ${e.message ?? 'Failed to get indexed string'}');
    }
  }
}
