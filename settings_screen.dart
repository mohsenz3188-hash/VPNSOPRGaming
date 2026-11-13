import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _dnsCtrl;
  late bool _bypassLan;

  @override
  void initState() {
    super.initState();
    final engine = context.read<VpnEngineService>();
    _dnsCtrl = TextEditingController(text: engine.customDns);
    _bypassLan = engine.bypassLan;
  }

  @override
  void dispose() {
    _dnsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.read<VpnEngineService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings & About',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Network & DNS',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dnsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Primary DNS (e.g. 1.1.1.1 / 8.8.8.8)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bypass LAN Subnets'),
                    subtitle: const Text(
                        'Keep local router & LAN traffic outside the tunnel'),
                    value: _bypassLan,
                    onChanged: (v) => setState(() => _bypassLan = v),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        engine.updateSettings(
                          dns: _dnsCtrl.text,
                          bypassLan: _bypassLan,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings saved')),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.shield_moon_rounded,
                  color: DragonColors.electricBlue),
              title: Text('VPN SOPR Gaming v1.0.0'),
              subtitle: Text(
                'Multi-Protocol Engine: WireGuard + Xray/V2Ray + OpenVPN\n'
                'Cyberpunk Dragon Edition',
                style: TextStyle(color: DragonColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
