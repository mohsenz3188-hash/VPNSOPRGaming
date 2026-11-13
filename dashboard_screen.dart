import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final state = engine.connectionState;
    final isConnected = state == VpnConnectionState.connected;
    final isBusy = state == VpnConnectionState.connecting ||
        state == VpnConnectionState.disconnecting;
    final active = engine.activeConfig;

    final coreColor = isConnected
        ? DragonColors.electricBlue
        : isBusy
            ? DragonColors.neonPurple
            : DragonColors.crimsonRed;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomPaint(
                  size: const Size(38, 38),
                  painter: DragonLogoPainter(
                    primary: DragonColors.electricBlue,
                    secondary: coreColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VPN SOPR Gaming',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      'وی پی ان سوپر گیمینگ',
                      style: TextStyle(
                        fontSize: 11,
                        color: DragonColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: DragonColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: coreColor.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    active?.pingMs != null && active!.pingMs! > 0
                        ? '${active.pingMs} ms'
                        : '-- ms',
                    style: TextStyle(
                      color: coreColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glow = 16 + (_pulseController.value * 18);
                  return GestureDetector(
                    onTap: engine.toggleConnection,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 196,
                      height: 196,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            coreColor.withValues(alpha: 0.25),
                            DragonColors.charcoal,
                          ],
                        ),
                        border: Border.all(color: coreColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: coreColor.withValues(alpha: 0.55),
                            blurRadius: glow,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isConnected
                                ? Icons.shield_rounded
                                : Icons.power_settings_new_rounded,
                            size: 56,
                            color: coreColor,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            state.name.toUpperCase(),
                            style: TextStyle(
                              color: coreColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            engine.duration,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              color: DragonColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: coreColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            active != null
                                ? '${active.name} (${active.protocolLabel})'
                                : 'No config imported — add one in Configs',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 22, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem('UPLOAD', engine.uploadSpeed,
                            DragonColors.crimsonRed, Icons.arrow_upward),
                        _statItem('DOWNLOAD', engine.downloadSpeed,
                            DragonColors.electricBlue, Icons.arrow_downward),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SMART ROUTING MODE',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.3,
                fontWeight: FontWeight.bold,
                color: DragonColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _modeCard(
                  engine,
                  RoutingMode.gaming,
                  'Smart Gaming',
                  'Low Ping / UDP',
                  Icons.sports_esports_rounded,
                  DragonColors.crimsonRed,
                ),
                const SizedBox(width: 10),
                _modeCard(
                  engine,
                  RoutingMode.web,
                  'Web / Stream',
                  'High Throughput',
                  Icons.public_rounded,
                  DragonColors.electricBlue,
                ),
                const SizedBox(width: 10),
                _modeCard(
                  engine,
                  RoutingMode.manual,
                  'Manual',
                  'Selected Config',
                  Icons.tune_rounded,
                  DragonColors.neonPurple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: DragonColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _modeCard(
    VpnEngineService engine,
    RoutingMode mode,
    String title,
    String subtitle,
    IconData icon,
    Color accent,
  ) {
    final selected = engine.routingMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => engine.setRoutingMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.16)
                : DragonColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : Colors.white12,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? accent : DragonColors.textSecondary),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? DragonColors.textPrimary : DragonColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: DragonColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
