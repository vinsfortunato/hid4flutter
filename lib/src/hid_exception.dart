class HidException implements Exception {
  HidException([this.message]);

  final String? message;
}

class HidReadException extends HidException {
  HidReadException([String? message]) : super(message);
}

class HidReadTimeoutException extends HidException {
  HidReadTimeoutException([String? message]) : super(message);
}

class HidWriteException extends HidException {
  HidWriteException([String? message]) : super(message);
}

class HidDeviceNotOpenException extends HidException {
  HidDeviceNotOpenException([String? message]) : super(message);
}
