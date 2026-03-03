// ============================================================================
// 📁 widgets/ble_status_indicator.dart
// ============================================================================
// Petit badge affichant l'état de la connexion BLE en temps réel.
// À placer dans l'AppBar pour une visibilité permanente.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/ble_service.dart';

class BleStatusIndicator extends StatefulWidget {
  const BleStatusIndicator({super.key});

  @override
  State<BleStatusIndicator> createState() => _BleStatusIndicatorState();
}

class _BleStatusIndicatorState extends State<BleStatusIndicator> {
  late StreamSubscription<BleConnectionState> _sub;
  BleConnectionState _state = BleService.instance.currentState;

  @override
  void initState() {
    super.initState();
    _sub = BleService.instance.stateStream.listen(
      (s) => setState(() => _state = s),
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _state == BleConnectionState.connected;
    final connecting =
        _state == BleConnectionState.connecting ||
        _state == BleConnectionState.scanning;
    final error = _state == BleConnectionState.error;

    final Color color = connected
        ? AppConstants.successColor
        : error
        ? AppConstants.dangerColor
        : connecting
        ? AppConstants.accentColor
        : const Color(0xFF999999);

    final String label = connected
        ? 'Connecté'
        : connecting
        ? 'Connexion...'
        : error
        ? 'Erreur'
        : 'Déconnecté';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connecting)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else
            Icon(
              connected
                  ? Icons.bluetooth_connected
                  : error
                  ? Icons.bluetooth_disabled
                  : Icons.bluetooth,
              size: 14,
              color: color,
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
