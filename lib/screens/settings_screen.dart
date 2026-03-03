import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/constants.dart';
import '../services/ble_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';
import '../widgets/ble_status_indicator.dart';

typedef SettingsChangedCallback =
    void Function({
      String? emergencyMessage,
      int? scrollSpeedMs,
      int? blinkIntervalMs,
      int? brightness,
    });

class SettingsScreen extends StatefulWidget {
  final SettingsChangedCallback? onSettingsChanged;

  const SettingsScreen({super.key, this.onSettingsChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _emergencyMessage;
  late int _scrollSpeedMs;
  late int _blinkIntervalMs;
  late int _brightness;

  BleConnectionState _bleState = BleService.instance.currentState;
  StreamSubscription<BleConnectionState>? _bleSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isScanning = false;
  List<ScanResult> _foundDevices = [];

  static const Map<int, String> _speedOptions = {
    100: 'Lent',
    60: 'Normal',
    30: 'Rapide',
  };

  @override
  void initState() {
    super.initState();
    final storage = StorageService.instance;
    _emergencyMessage = storage.emergencyMessage;
    _scrollSpeedMs = storage.scrollSpeedMs;
    _blinkIntervalMs = storage.blinkIntervalMs;
    _brightness = storage.brightness;
    _bleSub = BleService.instance.stateStream.listen(
      (state) => setState(() => _bleState = state),
    );
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _foundDevices = [];
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final map = <String, ScanResult>{};
      for (final r in results) {
        if (r.device.platformName.isNotEmpty) {
          map[r.device.remoteId.toString()] = r;
        }
      }
      if (mounted) setState(() => _foundDevices = map.values.toList());
    });

    FlutterBluePlus.isScanning.where((v) => v == false).first.then((_) {
      _scanSub?.cancel();
      if (mounted) setState(() => _isScanning = false);
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    setState(() {
      _isScanning = false;
      _foundDevices = [];
    });
    BleService.instance.connectToDevice(device).catchError((_) {});
  }

  Future<void> _editEmergencyMessage() async {
    final controller = TextEditingController(text: _emergencyMessage);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppConstants.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          ),
          title: const Text(
            'Message d\'urgence',
            style: TextStyle(
              color: AppConstants.accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Ex: HELP, SOS, DANGER...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: AppConstants.surfaceColor,
              prefixIcon: const Icon(
                Icons.warning_amber_rounded,
                color: AppConstants.dangerColor,
                size: 20,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: AppConstants.accentColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                ),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _emergencyMessage = result.toUpperCase();
      });
      StorageService.instance.emergencyMessage = _emergencyMessage;
      widget.onSettingsChanged?.call(emergencyMessage: _emergencyMessage);
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          _buildSectionHeader('Connexion'),
          const SizedBox(height: 8),
          _buildBluetoothTile(),
          if (_foundDevices.isNotEmpty || _isScanning) ...[
            const SizedBox(height: 8),
            _buildDeviceList(),
          ],
          const SizedBox(height: 20),
          _buildSectionHeader('Panneau LED'),
          const SizedBox(height: 8),
          _buildGroupedCard([
            _buildBrightnessContent(),
            _buildScrollSpeedContent(),
            _buildBlinkSpeedContent(),
          ]),
          const SizedBox(height: 20),
          _buildSectionHeader('Sécurité'),
          const SizedBox(height: 8),
          _buildEmergencyTile(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppConstants.backgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppConstants.borderColor),
      ),
      title: const Text(
        'Paramètres',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppConstants.accentColor,
          letterSpacing: 0.5,
        ),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: BleStatusIndicator(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppConstants.accentColor.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    return AppCard(
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppConstants.borderColor,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyTile() {
    return AppCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: AppConstants.accentColor,
            size: 22,
          ),
        ),
        title: const Text(
          'Message d\'urgence',
          style: TextStyle(
            color: AppConstants.accentColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _emergencyMessage,
          style: TextStyle(
            color: AppConstants.accentColor.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppConstants.accentColor.withValues(alpha: 0.4),
        ),
        onTap: _editEmergencyMessage,
      ),
    );
  }

  Widget _buildScrollSpeedContent() {
    final currentLabel = _speedOptions[_scrollSpeedMs] ?? '${_scrollSpeedMs}ms';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.speed,
              color: AppConstants.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vitesse de défilement',
                  style: TextStyle(
                    color: AppConstants.accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentLabel,
                  style: TextStyle(
                    color: AppConstants.accentColor.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _speedOptions.entries.map((entry) {
              final isSelected = _scrollSpeedMs == entry.key;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _scrollSpeedMs = entry.key);
                    StorageService.instance.scrollSpeedMs = entry.key;
                    widget.onSettingsChanged?.call(scrollSpeedMs: entry.key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppConstants.accentColor
                          : AppConstants.backgroundColor,
                      borderRadius: BorderRadius.circular(
                        AppConstants.smallRadius,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? AppConstants.accentColor
                            : AppConstants.borderColor,
                      ),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppConstants.accentColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static const Map<int, String> _blinkOptions = {
    800: 'Lent',
    500: 'Normal',
    250: 'Rapide',
  };

  Widget _buildBlinkSpeedContent() {
    final currentLabel =
        _blinkOptions[_blinkIntervalMs] ?? '${_blinkIntervalMs}ms';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.visibility,
              color: AppConstants.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vitesse de clignotement',
                  style: TextStyle(
                    color: AppConstants.accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentLabel,
                  style: TextStyle(
                    color: AppConstants.accentColor.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _blinkOptions.entries.map((entry) {
              final isSelected = _blinkIntervalMs == entry.key;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _blinkIntervalMs = entry.key);
                    StorageService.instance.blinkIntervalMs = entry.key;
                    widget.onSettingsChanged?.call(blinkIntervalMs: entry.key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppConstants.accentColor
                          : AppConstants.backgroundColor,
                      borderRadius: BorderRadius.circular(
                        AppConstants.smallRadius,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? AppConstants.accentColor
                            : AppConstants.borderColor,
                      ),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppConstants.accentColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessContent() {
    final percent = (_brightness / 255 * 100).round();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.brightness_6,
                  color: AppConstants.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Luminosité',
                  style: TextStyle(
                    color: AppConstants.accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$percent %',
                style: TextStyle(
                  color: AppConstants.accentColor.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppConstants.accentColor,
              inactiveTrackColor: AppConstants.borderColor,
              thumbColor: AppConstants.accentColor,
              overlayColor: AppConstants.accentColor.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _brightness.toDouble(),
              min: 5,
              max: 255,
              onChanged: (value) {
                setState(() => _brightness = value.round());
              },
              onChangeEnd: (value) {
                final b = value.round();
                StorageService.instance.brightness = b;
                BleService.instance.sendBrightness(b);
                widget.onSettingsChanged?.call(brightness: b);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTile() {
    final connected = _bleState == BleConnectionState.connected;
    final connecting =
        _bleState == BleConnectionState.connecting ||
        _bleState == BleConnectionState.scanning;
    final error = _bleState == BleConnectionState.error;

    final Color iconBg = connected
        ? AppConstants.successColor.withValues(alpha: 0.12)
        : error
        ? AppConstants.dangerColor.withValues(alpha: 0.12)
        : AppConstants.accentColor.withValues(alpha: 0.08);
    final Color iconColor = connected
        ? AppConstants.successColor
        : error
        ? AppConstants.dangerColor
        : AppConstants.accentColor;
    final IconData icon = connected
        ? Icons.bluetooth_connected
        : connecting
        ? Icons.bluetooth_searching
        : error
        ? Icons.bluetooth_disabled
        : Icons.bluetooth;
    final String subtitle = connected
        ? 'Connecté — appuyez pour déconnecter'
        : connecting
        ? 'Connexion en cours...'
        : _isScanning
        ? 'Scan en cours — appuyez pour arrêter'
        : error
        ? 'Échec — appuyez pour réessayer'
        : 'Non connecté — appuyez pour scanner';

    return AppCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: (connecting || _isScanning)
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppConstants.accentColor,
                  ),
                )
              : Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          connected ? 'Panneau LED connecté' : 'Connexion Bluetooth',
          style: const TextStyle(
            color: AppConstants.accentColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppConstants.accentColor.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
        trailing: connecting
            ? null
            : Icon(
                connected
                    ? Icons.link_off
                    : _isScanning
                    ? Icons.stop_circle_outlined
                    : Icons.search,
                color: AppConstants.accentColor.withValues(alpha: 0.4),
                size: 20,
              ),
        onTap: () {
          if (connected) {
            BleService.instance.disconnect();
          } else if (_isScanning) {
            FlutterBluePlus.stopScan();
            _scanSub?.cancel();
            setState(() {
              _isScanning = false;
              _foundDevices = [];
            });
          } else {
            _startScan();
          }
        },
      ),
    );
  }

  Widget _buildDeviceList() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                if (_isScanning) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppConstants.accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _isScanning ? 'Recherche en cours...' : 'Appareils trouvés',
                  style: TextStyle(
                    color: AppConstants.accentColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          if (_foundDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Aucun appareil détecté pour l\'instant...',
                style: TextStyle(
                  color: AppConstants.accentColor.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
              ),
            )
          else
            ...List.generate(_foundDevices.length, (i) {
              final r = _foundDevices[i];
              final name = r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : r.device.remoteId.toString();
              final isLast = i == _foundDevices.length - 1;
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppConstants.accentColor.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.bluetooth,
                        color: AppConstants.accentColor,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: AppConstants.accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${r.device.remoteId}  ·  ${r.rssi} dBm',
                      style: TextStyle(
                        color: AppConstants.accentColor.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 13,
                      color: AppConstants.accentColor,
                    ),
                    onTap: () => _connectToDevice(r.device),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppConstants.borderColor,
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
