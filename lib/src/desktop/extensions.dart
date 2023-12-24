import 'dart:ffi';
import 'package:ffi/ffi.dart';

extension CharPointerToString on Pointer<Char> {
  String toDartString() {
    return cast<Utf8>().toDartString();
  }
}

extension WCharPointerToString on Pointer<WChar> {
  String toDartString() {
    return cast<Utf16>().toDartString();
  }
}

extension StringToChar on String {
  Pointer<Char> toCharPointer({Allocator allocator = malloc}) {
    return toNativeUtf8(allocator: allocator).cast<Char>();
  }

  Pointer<WChar> toWCharPointer({Allocator allocator = malloc}) {
    return toNativeUtf16(allocator: allocator).cast<WChar>();
  }
}
