#include "include/hid4flutter/hid4flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "hid4flutter_plugin_private.h"

#define HID4FLUTTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), hid4flutter_plugin_get_type(), \
                              Hid4flutterPlugin))

struct _Hid4flutterPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(Hid4flutterPlugin, hid4flutter_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void hid4flutter_plugin_handle_method_call(
    Hid4flutterPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void hid4flutter_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(hid4flutter_plugin_parent_class)->dispose(object);
}

static void hid4flutter_plugin_class_init(Hid4flutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = hid4flutter_plugin_dispose;
}

static void hid4flutter_plugin_init(Hid4flutterPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  Hid4flutterPlugin* plugin = HID4FLUTTER_PLUGIN(user_data);
  hid4flutter_plugin_handle_method_call(plugin, method_call);
}

void hid4flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  Hid4flutterPlugin* plugin = HID4FLUTTER_PLUGIN(
      g_object_new(hid4flutter_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "hid4flutter",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
