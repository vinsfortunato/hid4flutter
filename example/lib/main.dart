import 'package:flutter/material.dart';
import 'package:hid4flutter/hid4flutter.dart';

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
          ),
        );
      },
    );
  }
}
