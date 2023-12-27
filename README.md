# hid4flutter

[![pub](https://img.shields.io/badge/pub-0.0.1-blue)](https://pub.dev/packages/hid4flutter)
[![license: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

`hid4flutter` is a Flutter plugin that enables communication with HID (Human Interface Device) devices from a Flutter application. 

## Disclaimer

**Warning:** This plugin is currently under development, and the API is subject to change. Use it at your own risk in a production environment.

Contributions are welcome! Feel free to submit issues and pull requests to help improve this plugin.

## Supported Platforms

- Windows
- macOS
- Linux

**Note:** Support for other platforms will be added in future releases.

### Implementation details

Desktop support (Windows/macOS/Linux) is achieved by using [hidapi](https://github.com/libusb/hidapi) and Dart FFI.

## Installation

To install `hid4flutter` in a Flutter project, follow these steps:

1. Add the following line to the `pubspec.yaml` file:

    ```yaml
    dependencies:
      hid4flutter: ^0.0.1
    ```

    Replace `^0.0.1` with the latest version of the plugin.

2. Run the following command to install the dependency:

    ```bash
    flutter pub get
    ```

3. Import the `hid4flutter` package in your Dart code:

    ```dart
    import 'package:hid4flutter/hid4flutter.dart';
    ```

4. Follow the documentation and examples to integrate and communicate with HID devices in your Flutter application.

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

await device.open();

// Send an output report of 32 bytes (all zeroes).
// The reportId is optional (default is 0x00).
// It will be prefixed to the data as per HID rules.
Uint8List data = Uint8List(32);
int bytesWritten = await device.write(reportId: 0x00, reportData);

// This will print 'Sent 33 bytes.' 
// (32 bytes + 1 byte for reportId).
print('Sent $bytesWritten bytes.');

// Close when no more needed
await device.close();
```

### Receive Input Report

```dart
final HidDevice device = ...

await device.open();

// Receive a report of 32 bytes with timeout of 2 seconds.
Uint8List data = await device.read(32, timeout: const Duration(seconds: 2));

// First byte is always the reportId.
int reportId = data[0];

print('Received report with id $reportId: $data.');

// Close when no more needed
await device.close();
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
