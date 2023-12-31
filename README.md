# hid4flutter

[![pub](https://img.shields.io/badge/pub-0.1.1-blue)](https://pub.dev/packages/hid4flutter)
[![license: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

`hid4flutter` is a Flutter plugin that enables communication with HID (Human Interface Device) devices from a Flutter application.

## Disclaimer

**Warning:** This plugin is currently under development, and the API may be subject to change. Use it at your own risk in a production environment.

Some features are planned but their development has been postponed. Check the list [here](#planned-features).

Contributions are welcome! Feel free to submit issues and pull requests to help improve this plugin.

## Supported Platforms

- Windows
- macOS
- Linux (currently requires to install libhidapi-hidraw0 manually, see [installation](#installation))

**Note:** Some platforms [will be supported](#planned-platform-support) in future releases.

### Implementation details

Desktop support (Windows/macOS/Linux) is achieved by using [hidapi](https://github.com/libusb/hidapi) and Dart FFI.

### Planned platform support

Support for the following platforms is planned to be added in the near future:

- **Android**: can be easily supported using MethodChannel and Android HID.
- **Web**: experimental WebHID can be used to support the Web platform.

## Installation

To install `hid4flutter` in a Flutter project, follow these steps:

1. Add the following line to the `pubspec.yaml` file:

    ```yaml
    dependencies:
      hid4flutter: ^0.1.1
    ```

    Replace `^0.1.1` with the latest version of the plugin.

2. Run the following command to install the dependency:

    ```bash
    flutter pub get
    ```

3. Import the `hid4flutter` package in your Dart code:

    ```dart
    import 'package:hid4flutter/hid4flutter.dart';
    ```

4. Follow the documentation and examples to integrate and communicate with HID devices in your Flutter application.


**Note:** On Linux platform it is currently required to install `hidapi` manually by executing the following command

```bash
sudo apt-get install libhidapi-hidraw0
```

Currently `hidapi` doesn't get compiled on Linux when building this library. It will be in future releases when this
issue will be addressed.

## Usage

### Get all connected devices list

```dart
List<HidDevice> devices = await Hid.getDevices();

// Do something with the list
```

### Get device by vendorId and productId

```dart
List<HidDevice> devices = await Hid.getDevices(vendorId: 0x55, productId: 0x13);

// Since multiple devices can match the same vendorId 
// and productId, get the first device or null.
HidDevice? device = devices.firstOrNull;

// Do something with the device
```

### Send Output Report

```dart
final HidDevice device = ...

try {
  await device.open();

  // Send an Output report of 32 bytes (all zeroes).
  // The reportId is optional (default is 0x00).
  // It will be prefixed to the data as per HID rules.
  Uint8List data = Uint8List(32);
  await device.sendReport(reportId: 0x00, reportData);
} finally {
  await device.close();
}
```

### Receive Input Report

```dart
final HidDevice device = ...

try {
  await device.open();

  // Receive a report of 32 bytes with timeout of 2 seconds.
  Uint8List data = await device.receiveReport(32, timeout: const Duration(seconds: 2));

  // First byte is always the reportId.
  int reportId = data[0];

  print('Received report with id $reportId: $data.');
} finally {
  await device.close();
}
```

## Planned features

These features are planned to be developed but currently not supported:

- **Get device HID report descriptor**: request the report descriptor from the device
  and return it as a structured objects represeting the HID collections.
  Using hidapi version >= 0.14.0 gives the ability to easily get
  the report descriptor bytes. A parser is required however to get a
  structured object.
- **Notify about device connection/disconnection events**: add the possibility to
  listen connection/disconnection events to avoid polling getDevices(...) function.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
