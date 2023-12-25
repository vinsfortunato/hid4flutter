# hid4flutter

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

`hid4flutter` is a Flutter plugin that enables communication with HID (Human Interface Device) devices from a Flutter application. 

## Disclaimer

**Warning:** This plugin is currently under development, and the API is subject to change. Use it at your own risk in a production environment.

Contributions are welcome! Feel free to submit issues and pull requests to help improve this plugin.

## Supported Platforms

- [x] Windows
- [ ] macOS
- [ ] Linux
- [ ] Android
- [ ] iOS

**Note:** As of now, `hid4flutter` is only supported on Windows. Support for other platforms will be added in future releases.

## Installation

To install `hid4flutter` in a Flutter project, follow these steps:

1. Add the following line to the `pubspec.yaml` file:

    ```yaml
    dependencies:
      hid4flutter: ^0.1.0
    ```

    Replace `^0.1.0` with the latest version of the plugin.

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

### List attached HID devices

```dart
await Hid.init();

List<HidDevice> devices = await Hid.getAttachedDevices();

// Do something with the list

await Hid.exit();
```

### Get device by vendorId and productId

```dart
await Hid.init();

const vendorId = 0x55;
const productId = 0x13;

List<HidDevice> devices = await Hid.getAttachedDevices();

HidDevice? device = devices
    .where((dev) => dev.vendorId == vendorId)
    .where((dev) => dev.productId == productId)
    .firstOrNull;

// Do something with the device

await Hid.exit();
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.