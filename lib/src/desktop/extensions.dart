import 'dart:ffi';
import 'package:ffi/ffi.dart';

extension CharPointerToString on Pointer<Char> {
  String toDartString({int? length}) {
    _ensureNotNullptr('toDartString');
    final codeUnits = this;
    if (length == null) {
      return _toUnknownLengthString(codeUnits);
    } else {
      RangeError.checkNotNegative(length, 'length');
      return _toKnownLengthString(codeUnits, length);
    }
  }

  static String _toKnownLengthString(Pointer<Char> codeUnits, int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      final char = codeUnits.elementAt(i).value;
      buffer.writeCharCode(char);
    }
    return buffer.toString();
  }

  static String _toUnknownLengthString(Pointer<Char> codeUnits) {
    final buffer = StringBuffer();
    var i = 0;
    while (true) {
      final char = codeUnits.elementAt(i).value;
      if (char == 0) {
        return buffer.toString();
      }
      buffer.writeCharCode(char);
      i++;
    }
  }

  void _ensureNotNullptr(String operation) {
    if (this == nullptr) {
      throw UnsupportedError(
          "Operation '$operation' not allowed on a 'nullptr'.");
    }
  }
}

extension WCharPointerToString on Pointer<WChar> {
  String toDartString({int? length}) {
    _ensureNotNullptr('toDartString');
    final codeUnits = this;
    if (length == null) {
      return _toUnknownLengthString(codeUnits);
    } else {
      RangeError.checkNotNegative(length, 'length');
      return _toKnownLengthString(codeUnits, length);
    }
  }

  static String _toKnownLengthString(Pointer<WChar> codeUnits, int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      final char = codeUnits.elementAt(i).value;
      buffer.writeCharCode(char);
    }
    return buffer.toString();
  }

  static String _toUnknownLengthString(Pointer<WChar> codeUnits) {
    final buffer = StringBuffer();
    var i = 0;
    while (true) {
      final char = codeUnits.elementAt(i).value;
      if (char == 0) {
        return buffer.toString();
      }
      buffer.writeCharCode(char);
      i++;
    }
  }

  void _ensureNotNullptr(String operation) {
    if (this == nullptr) {
      throw UnsupportedError(
          "Operation '$operation' not allowed on a 'nullptr'.");
    }
  }
}

extension StringToChar on String {
  Pointer<Char> toCharPointer({Allocator allocator = malloc}) {
    final units = codeUnits;
    final Pointer<Char> result = allocator<Char>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      result[i] = units[i];
    }
    result[units.length] = 0;
    return result;
  }

  Pointer<WChar> toWCharPointer({Allocator allocator = malloc}) {
    final units = codeUnits;
    final Pointer<WChar> result = allocator<WChar>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      result[i] = units[i];
    }
    result[units.length] = 0;
    return result;
  }
}
