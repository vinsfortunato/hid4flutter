#include "include/hid4flutter/hid4flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "hid4flutter_plugin.h"

void Hid4FlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  hid4flutter::Hid4FlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
