import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hid4flutter/hid4flutter.dart';

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

class DeviceScreen extends StatefulWidget {
  final HidDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  StreamSubscription<int>? _inputSub;
  bool _shouldListen = false;
  Timer? _redrawTimer;
  final List<int> _inputBytes = [];
  final ScrollController _inputScrollController = ScrollController();

  final _reportIdController = TextEditingController(text: '00');
  final _hexController = TextEditingController();
  bool _sending = false;
  String? _sendError;

  @override
  void dispose() {
    _redrawTimer?.cancel();
    _inputSub?.cancel(); // returns quickly now
    _inputScrollController.dispose();
    _reportIdController.dispose();
    _hexController.dispose();
    if (widget.device.isOpen) widget.device.close();
    super.dispose();
  }

  Future<void> _toggleOpen() async {
    try {
      if (widget.device.isOpen) {
        await _stopListening();
        await widget.device.close();
      } else {
        await widget.device.open();
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _scheduleRedraw() {
    _redrawTimer?.cancel();
    _redrawTimer = Timer(const Duration(milliseconds: 32), () {
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_inputScrollController.hasClients) {
          _inputScrollController
              .jumpTo(_inputScrollController.position.maxScrollExtent);
        }
      });
    });
  }

  void _startListening() {
    _shouldListen = true;
    _subscribeToStream();
    setState(() {});
  }

  void _subscribeToStream() {
    if (_inputSub != null) return;
    _inputSub = widget.device.inputStream().listen(
      (byte) {
        _inputBytes.add(byte);
        _scheduleRedraw();
      },
      onError: (e) {
        _inputSub = null;
        _shouldListen = false;
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
          setState(() {});
        }
      },
      onDone: () {
        _inputSub = null;
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _stopListening() async {
    _shouldListen = false;
    await _inputSub?.cancel();
    _inputSub = null;
    setState(() {});
  }

  Future<void> _sendReport() async {
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final reportId = int.parse(
        _reportIdController.text.replaceAll('0x', '').replaceAll(' ', ''),
        radix: 16,
      );
      final bytes = _hexToBytes(_hexController.text);
      await widget.device.sendReport(bytes, reportId: reportId);
    } catch (e) {
      setState(() => _sendError = '$e');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final title =
        device.productName.isNotEmpty ? device.productName : 'Unknown Device';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              icon: Icon(device.isOpen ? Icons.usb_off : Icons.usb),
              label: Text(device.isOpen ? 'Close' : 'Open'),
              onPressed: _toggleOpen,
              style: FilledButton.styleFrom(
                backgroundColor: device.isOpen
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(text: 'Info'),
                Tab(text: 'Reports'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _InfoTab(device: device),
                  _ReportsTab(
                    device: device,
                    inputBytes: _inputBytes,
                    inputScrollController: _inputScrollController,
                    isListening: _shouldListen,
                    onStartListening: _startListening,
                    onStopListening: _stopListening,
                    onClearInput: () => setState(() {
                      _inputBytes.clear();
                    }),
                    reportIdController: _reportIdController,
                    hexController: _hexController,
                    sending: _sending,
                    sendError: _sendError,
                    onSend: _sendReport,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final HidDevice device;

  const _InfoTab({required this.device});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoRow('Path', device.path),
        _InfoRow('Vendor ID',
            '0x${device.vendorId.toRadixString(16).padLeft(4, '0').toUpperCase()}'),
        _InfoRow('Product ID',
            '0x${device.productId.toRadixString(16).padLeft(4, '0').toUpperCase()}'),
        _InfoRow('Serial Number', device.serialNumber),
        _InfoRow('Release Number',
            '0x${device.releaseNumber.toRadixString(16).toUpperCase()}'),
        _InfoRow('Manufacturer', device.manufacturer),
        _InfoRow('Product Name', device.productName),
        _InfoRow('Usage Page',
            '0x${device.usagePage.toRadixString(16).padLeft(4, '0').toUpperCase()}'),
        _InfoRow('Usage',
            '0x${device.usage.toRadixString(16).padLeft(4, '0').toUpperCase()}'),
        _InfoRow('Interface Number', '${device.interfaceNumber}'),
        _InfoRow('Bus Type', '${device.busType}'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  final HidDevice device;
  final List<int> inputBytes;
  final ScrollController inputScrollController;
  final bool isListening;
  final VoidCallback onStartListening;
  final VoidCallback onStopListening;
  final VoidCallback onClearInput;
  final TextEditingController reportIdController;
  final TextEditingController hexController;
  final bool sending;
  final String? sendError;
  final Future<void> Function() onSend;

  const _ReportsTab({
    required this.device,
    required this.inputBytes,
    required this.inputScrollController,
    required this.isListening,
    required this.onStartListening,
    required this.onStopListening,
    required this.onClearInput,
    required this.reportIdController,
    required this.hexController,
    required this.sending,
    required this.sendError,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _inputSection(context)),
        const Divider(height: 1, thickness: 1),
        Expanded(child: _outputSection(context)),
      ],
    );
  }

  Widget _inputSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Text('Input',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              TextButton.icon(
                icon: Icon(isListening ? Icons.stop : Icons.play_arrow),
                label: Text(isListening ? 'Stop' : 'Listen'),
                onPressed: device.isOpen
                    ? (isListening ? onStopListening : onStartListening)
                    : null,
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
                onPressed: onClearInput,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _HexViewer(
            bytes: inputBytes,
            scrollController: inputScrollController,
          ),
        ),
      ],
    );
  }

  Widget _outputSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text('Output',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: reportIdController,
                  decoration: const InputDecoration(
                    labelText: 'Report ID',
                    hintText: '00',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: device.isOpen && !sending ? onSend : null,
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            controller: hexController,
            decoration: const InputDecoration(
              labelText: 'Hex data',
              hintText: '01 02 03 FF',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 3,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        if (sendError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              sendError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _HexViewer extends StatelessWidget {
  final List<int> bytes;
  final ScrollController scrollController;

  const _HexViewer({required this.bytes, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    if (bytes.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.grey)),
      );
    }

    final cs = Theme.of(context).colorScheme;
    const cols = 8;
    final rowCount = (bytes.length / cols).ceil();

    return Container(
      color: cs.surfaceContainerLow,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: rowCount,
        itemBuilder: (_, i) {
          final start = i * cols;
          final end = (start + cols).clamp(0, bytes.length);
          return _buildRow(bytes.sublist(start, end), start, cs);
        },
      ),
    );
  }

  Widget _buildRow(List<int> row, int offset, ColorScheme cs) {
    const cols = 8;
    const base =
        TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.6);
    final offsetStyle = base.copyWith(color: cs.outline);
    final hexStyle = base.copyWith(color: cs.onSurface);
    final asciiStyle = base.copyWith(color: cs.primary);
    final dotStyle = base.copyWith(color: cs.outlineVariant);

    final spans = <TextSpan>[
      TextSpan(
        text: '${offset.toRadixString(16).padLeft(4, '0').toUpperCase()}  ',
        style: offsetStyle,
      ),
    ];

    for (int i = 0; i < cols; i++) {
      if (i < row.length) {
        final hex = row[i].toRadixString(16).padLeft(2, '0').toUpperCase();
        spans
            .add(TextSpan(text: i < cols - 1 ? '$hex ' : hex, style: hexStyle));
      } else {
        spans.add(TextSpan(text: i < cols - 1 ? '   ' : '  ', style: hexStyle));
      }
    }

    spans.add(TextSpan(text: '  ', style: base));

    for (int i = 0; i < row.length; i++) {
      final b = row[i];
      final isPrint = b >= 0x20 && b < 0x7F;
      spans.add(TextSpan(
        text: isPrint ? String.fromCharCode(b) : '.',
        style: isPrint ? asciiStyle : dotStyle,
      ));
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}
