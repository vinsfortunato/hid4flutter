#ifndef FLUTTER_PLUGIN_HID4FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_HID4FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace hid4flutter {

class Hid4flutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  Hid4flutterPlugin();

  virtual ~Hid4flutterPlugin();

  // Disallow copy and assign.
  Hid4flutterPlugin(const Hid4flutterPlugin&) = delete;
  Hid4flutterPlugin& operator=(const Hid4flutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace hid4flutter

#endif  // FLUTTER_PLUGIN_HID4FLUTTER_PLUGIN_H_
