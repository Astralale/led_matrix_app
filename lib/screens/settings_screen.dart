import 'package:flutter/material.dart';
import '../config/constants.dart';

class SettingsScreen extends StatefulWidget {
  final String emergencyMessage;

  const SettingsScreen({super.key, required this.emergencyMessage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _emergencyMessage;

  @override
  void initState() {
    super.initState();
    _emergencyMessage = widget.emergencyMessage;
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
          Navigator.pop(context, _emergencyMessage);
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
        onPressed: () => Navigator.pop(context, _emergencyMessage),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppConstants.borderColor),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppConstants.accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppConstants.accentColor.withOpacity(0.2),
              ),
            ),
            child: const Icon(
              Icons.settings,
              color: AppConstants.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Paramètres',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppConstants.accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
}
