## 0.1.1

### Fixed

- Fix macOS podspec summary and description.
- Fix test to clear pub publish warnings.

## 0.1.0

### Added

- Support for macOS platform.
- Support for Linux platform.
- Add filters to `Hid.getDevices(...)` method.
- Add a working flutter example application in /example/
- Add `inputStream()` method to `HidDevice` to get a stream of bytes received
  from the device as part of an input report.

### Changed

- Upgrade used hidapi version to `0.14.0`
- Remove `Hid.init()` and `Hid.exit()` methods. Resources are now freed automatically when all devices get closed.
- Change property `product` to `productName` in `HidDevice` class.
- Improve API naming and usage.
- Improve documentation.
- Remove android from apparently supported platforms in pubspec since it is still not supported.

### Fixed

- Compile hidapi on windows instead of bundling pre-compiled dylibs.
- Remove unused/unnecessary native code.
- Fix pointer of Char/WChar to String conversions.
- Fix input report receiving implementation on desktop platforms.

## 0.0.1

Initial release.

**Note:** As of now, `hid4flutter` is only supported on Windows. Support for other platforms will be added in future releases.
