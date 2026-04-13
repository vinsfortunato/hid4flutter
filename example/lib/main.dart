import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hid4flutter/hid4flutter.dart';

class _ReportPayload {
  final int reportId;
  final Uint8List bytes;
  const _ReportPayload(this.reportId, this.bytes);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true),
      home: const DeviceListScreen(),
    );
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  DeviceListScreenState createState() => DeviceListScreenState();
}

class DeviceListScreenState extends State<DeviceListScreen> {
  List<HidDevice> devices = [];

  @override
  void initState() {
    super.initState();
    _loadConnectedDevices();
  }

  Future<void> _loadConnectedDevices() async {
    try {
      List<HidDevice> connectedDevices = await Hid.getDevices();
      setState(() {
        devices = connectedDevices;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error getting connected devices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Connected Devices'),
      ),
      body: _buildDeviceList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {
          _loadConnectedDevices(),
        },
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (devices.isEmpty) {
      return const Center(
        child: Text('No connected devices'),
      );
    }

    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        HidDevice device = devices[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text('Device $index'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Path: ${device.path}'),
                Text('Vendor ID: 0x${device.vendorId.toRadixString(16)}'),
                Text('Product ID: 0x${device.productId.toRadixString(16)}'),
                Text('Serial Number: ${device.serialNumber}'),
                Text('Release Number: ${device.releaseNumber}'),
                Text('Manufacturer: ${device.manufacturer}'),
                Text('Product Name: ${device.productName}'),
                Text('Usage Page: 0x${device.usagePage.toRadixString(16)}'),
                Text('Usage: 0x${device.usage.toRadixString(16)}'),
                Text('Interface Number: ${device.interfaceNumber}'),
                Text('Bus Type: ${device.busType}'),
              ],
            ),
            trailing: device.isOpen
                ? const Icon(Icons.usb, color: Colors.green)
                : const Icon(Icons.usb, color: Colors.grey),
            onTap: () async {
              await _handleDeviceTap(device, index);
            },
            onLongPress: () async {
              await _handleDeviceLongPress(context, device, index);
            },
          ),
        );
      },
    );
  }

  Future<void> _handleDeviceTap(HidDevice device, int index) async {
    try {
      if (!device.isOpen) {
        await device.open();
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opened ${device.productName.isNotEmpty ? device.productName : 'device $index'}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await device.close();
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Closed ${device.productName.isNotEmpty ? device.productName : 'device $index'}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${device.isOpen ? 'Failed to close' : 'Failed to open'} device: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleDeviceLongPress(
      BuildContext context, HidDevice device, int index) async {
    if (!device.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open the device first to send data.')),
      );
      return;
    }

    final payload = await _promptReportPayload(context);
    if (payload == null) return;

    try {
      await device.sendReport(payload.bytes, reportId: payload.reportId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data sent.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }

  Future<_ReportPayload?> _promptReportPayload(BuildContext context) async {
    final hexController = TextEditingController();
    final reportIdController = TextEditingController(text: '00');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Send custom HEX bytes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reportIdController,
                decoration: const InputDecoration(
                  labelText: 'Report ID (hex, e.g. 00)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: hexController,
                decoration: const InputDecoration(
                  labelText: 'Data bytes (hex, e.g. 01 02 0A FF)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return null;

    try {
      final reportId = int.parse(
          reportIdController.text.replaceAll('0x', '').replaceAll(' ', ''),
          radix: 16);
      final bytes = _hexToBytes(hexController.text);
      return _ReportPayload(reportId, bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid input: $e')),
      );
      return null;
    }
  }
}


Uint8List _hexToBytes(String hexInput) {
  String s = hexInput
      .trim()
      .replaceAll(RegExp(r'0x', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (s.length % 2 != 0) s = '0$s';
  final out = Uint8List(s.length ~/ 2);
  for (int i = 0, j = 0; i < s.length; i += 2, j++) {
    out[j] = int.parse(s.substring(i, i + 2), radix: 16);
  }
  return out;
}
