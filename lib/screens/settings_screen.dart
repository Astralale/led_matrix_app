import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/ble_service.dart';

class SettingsScreen extends StatefulWidget {
  final String emergencyMessage;
  final int scrollSpeedMs;
  final int brightness;

  const SettingsScreen({
    super.key,
    required this.emergencyMessage,
    required this.scrollSpeedMs,
    required this.brightness,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _emergencyMessage;
  late int _scrollSpeedMs;
  late int _brightness;

  static const Map<int, String> _speedOptions = {
    100: 'Lent',
    60: 'Normal',
    30: 'Rapide',
  };

  @override
  void initState() {
    super.initState();
    _emergencyMessage = widget.emergencyMessage;
    _scrollSpeedMs = widget.scrollSpeedMs;
    _brightness = widget.brightness;
  }

  Map<String, dynamic> _buildResult() {
    return {
      'emergencyMessage': _emergencyMessage,
      'scrollSpeedMs': _scrollSpeedMs,
      'brightness': _brightness,
    };
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
                  color: AppConstants.accentColor.withOpacity(0.7),
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
                backgroundColor: AppConstants.dangerColor,
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
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _buildResult());
        }
      },
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            _buildSectionHeader('Urgence'),
            const SizedBox(height: 8),
            _buildEmergencyTile(),
            const SizedBox(height: 20),
            _buildSectionHeader('Défilement'),
            const SizedBox(height: 8),
            _buildScrollSpeedTile(),
            const SizedBox(height: 20),
            _buildSectionHeader('Panneau LED'),
            const SizedBox(height: 8),
            _buildBrightnessTile(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppConstants.backgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppConstants.accentColor),
        onPressed: () => Navigator.pop(context, _buildResult()),
      ),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppConstants.accentColor.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEmergencyTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.dangerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: AppConstants.dangerColor,
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
            color: AppConstants.accentColor.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppConstants.accentColor.withOpacity(0.4),
        ),
        onTap: _editEmergencyMessage,
      ),
    );
  }

  Widget _buildScrollSpeedTile() {
    final currentLabel = _speedOptions[_scrollSpeedMs] ?? '${_scrollSpeedMs}ms';

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.accentColor.withOpacity(0.08),
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
                      color: AppConstants.accentColor.withOpacity(0.5),
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
                    onTap: () => setState(() => _scrollSpeedMs = entry.key),
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
                              : AppConstants.accentColor.withOpacity(0.7),
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
      ),
    );
  }

  Widget _buildBrightnessTile() {
    final percent = (_brightness / 255 * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.accentColor.withOpacity(0.08),
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
                    color: AppConstants.accentColor.withOpacity(0.5),
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
                overlayColor: AppConstants.accentColor.withOpacity(0.1),
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
                  BleService.instance.sendBrightness(value.round());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
