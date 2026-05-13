import 'package:flutter/material.dart';
import 'package:hid4flutter/hid4flutter.dart';
import 'device_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<HidDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final devices = await Hid.getDevices();
      setState(() => _devices = devices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to list devices: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Connected Devices'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
      body: _devices.isEmpty
          ? const Center(child: Text('No connected devices'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                final name = device.productName.isNotEmpty
                    ? device.productName
                    : 'Unknown Device';
                final vid =
                    '0x${device.vendorId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
                final pid =
                    '0x${device.productId.toRadixString(16).padLeft(4, '0').toUpperCase()}';

                return ListTile(
                  leading: const Icon(Icons.usb),
                  title: Text(name),
                  subtitle:
                      Text('VID: $vid  PID: $pid  — ${device.manufacturer}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeviceScreen(device: device),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
