import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import '../models/vpn_config.dart';

enum VpnConnectionState { disconnected, connecting, connected, disconnecting }

class VpnEngineService extends ChangeNotifier {
  static const _prefsConfigsKey = 'vpn_sopr_configs';
  static const _prefsSelectedIdKey = 'vpn_sopr_selected_id';
  static const _prefsModeKey = 'vpn_sopr_routing_mode';
  static const _prefsDnsKey = 'vpn_sopr_custom_dns';
  static const _prefsBypassLanKey = 'vpn_sopr_bypass_lan';

  late final FlutterV2ray _v2ray;
  late final OpenVPN _openVpn;
  final WireGuardFlutterInterface _wireGuard = WireGuardFlutter.instance;

  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  RoutingMode _routingMode = RoutingMode.gaming;
  List<VpnConfig> _configs = [];
  String? _selectedConfigId;
  String _customDns = '1.1.1.1';
  bool _bypassLan = true;

  String _uploadSpeed = '0 KB/s';
  String _downloadSpeed = '0 KB/s';
  String _duration = '00:00:00';
  int? _activePingMs;
  final List<String> _logs = [];

  Timer? _durationTimer;
  DateTime? _connectedAt;
  bool _initialized = false;

  VpnConnectionState get connectionState => _connectionState;
  RoutingMode get routingMode => _routingMode;
  List<VpnConfig> get configs => List.unmodifiable(_configs);
  String? get selectedConfigId => _selectedConfigId;
  String get customDns => _customDns;
  bool get bypassLan => _bypassLan;
  String get uploadSpeed => _uploadSpeed;
  String get downloadSpeed => _downloadSpeed;
  String get duration => _duration;
  int? get activePingMs => _activePingMs;
  List<String> get logs => List.unmodifiable(_logs);

  VpnConfig? get activeConfig {
    if (_configs.isEmpty) return null;
    if (_selectedConfigId != null) {
      final found = _configs.where((c) => c.id == _selectedConfigId);
      if (found.isNotEmpty) return found.first;
    }
    return _configs.first;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (activeConfig?.protocol == VpnProtocol.v2ray) {
          _uploadSpeed = _formatBytesPerSec(status.uploadSpeed);
          _downloadSpeed = _formatBytesPerSec(status.downloadSpeed);
          _duration = status.duration;
          if (status.state == 'CONNECTED') {
            _setConnectedState();
          } else if (status.state == 'DISCONNECTED') {
            _setDisconnectedState();
          }
          notifyListeners();
        }
      },
    );

    await _v2ray.initializeV2Ray(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );

    _openVpn = OpenVPN(
      onVpnStatusChanged: (status) {
        if (status != null && activeConfig?.protocol == VpnProtocol.openvpn) {
          _uploadSpeed = _formatBytesPerSec(status.speedOut ?? 0);
          _downloadSpeed = _formatBytesPerSec(status.speedIn ?? 0);
          _duration = status.duration ?? _duration;
          notifyListeners();
        }
      },
      onVpnStageChanged: (stage, raw) {
        if (activeConfig?.protocol == VpnProtocol.openvpn) {
          _addLog('OpenVPN stage: ${stage.name}');
          if (stage.isConnected) {
            _setConnectedState();
          } else if (stage.isDisconnected) {
            _setDisconnectedState();
          }
          notifyListeners();
        }
      },
    );

    await _openVpn.initialize(
      groupIdentifier: 'group.com.vpnsopr.gaming',
      providerBundleIdentifier: 'com.vpnsopr.gaming.VPNExtension',
      localizedDescription: 'VPN SOPR Gaming',
    );

    await _wireGuard.initialize(interfaceName: 'wg_sopr0');
    _wireGuard.vpnStageSnapshot.listen((stage) {
      if (activeConfig?.protocol == VpnProtocol.wireguard) {
        _addLog('WireGuard stage: ${stage.name}');
        if (stage == VpnStage.connected) {
          _setConnectedState();
        } else if (stage == VpnStage.disconnected) {
          _setDisconnectedState();
        }
        notifyListeners();
      }
    });

    await _loadPreferences();
    _addLog('VPN SOPR Gaming engine initialized.');
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getString(_prefsConfigsKey);
    if (rawList != null && rawList.isNotEmpty) {
      _configs = VpnConfig.decodeList(rawList);
    }
    _selectedConfigId = prefs.getString(_prefsSelectedIdKey);
    final savedMode = prefs.getString(_prefsModeKey);
    if (savedMode != null) {
      _routingMode = RoutingMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => RoutingMode.gaming,
      );
    }
    _customDns = prefs.getString(_prefsDnsKey) ?? '1.1.1.1';
    _bypassLan = prefs.getBool(_prefsBypassLanKey) ?? true;
    notifyListeners();
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsConfigsKey, VpnConfig.encodeList(_configs));
    if (_selectedConfigId != null) {
      await prefs.setString(_prefsSelectedIdKey, _selectedConfigId!);
    }
  }

  Future<void> setRoutingMode(RoutingMode mode) async {
    _routingMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsModeKey, mode.name);
    _addLog('Switched routing mode to ${mode.name.toUpperCase()}');
    notifyListeners();
  }

  Future<void> updateSettings({required String dns, required bool bypassLan}) async {
    _customDns = dns.trim().isEmpty ? '1.1.1.1' : dns.trim();
    _bypassLan = bypassLan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDnsKey, _customDns);
    await prefs.setBool(_prefsBypassLanKey, _bypassLan);
    _addLog('Updated DNS=$_customDns, BypassLAN=$_bypassLan');
    notifyListeners();
  }

  void selectConfig(String id) {
    _selectedConfigId = id;
    _saveConfigs();
    notifyListeners();
  }

  Future<void> deleteConfig(String id) async {
    _configs.removeWhere((c) => c.id == id);
    if (_selectedConfigId == id) {
      _selectedConfigId = _configs.isNotEmpty ? _configs.first.id : null;
    }
    await _saveConfigs();
    notifyListeners();
  }

  Future<void> updateConfig(VpnConfig updated) async {
    final idx = _configs.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _configs[idx] = updated;
      await _saveConfigs();
      notifyListeners();
    }
  }

  VpnConfig? _pickSmartConfig() {
    if (_configs.isEmpty) return null;
    if (_routingMode == RoutingMode.manual) return activeConfig;

    final candidates = List<VpnConfig>.from(_configs);
    candidates.sort((a, b) {
      final scoreA = _scoreConfig(a, _routingMode);
      final scoreB = _scoreConfig(b, _routingMode);
      return scoreB.compareTo(scoreA);
    });
    return candidates.first;
  }

  int _scoreConfig(VpnConfig c, RoutingMode mode) {
    int score = 0;
    final ping = c.pingMs ?? 999;

    if (mode == RoutingMode.gaming) {
      if (c.protocol == VpnProtocol.wireguard) score += 500;
      if (c.protocol == VpnProtocol.v2ray && c.isUdpPreferred) score += 350;
      if (c.protocol == VpnProtocol.openvpn) score += 100;
      score += (1000 - ping.clamp(0, 999));
    } else {
      if (c.protocol == VpnProtocol.v2ray) score += 500;
      if (c.protocol == VpnProtocol.openvpn) score += 350;
      if (c.protocol == VpnProtocol.wireguard) score += 250;
      score += (500 - (ping.clamp(0, 999) ~/ 2));
    }
    return score;
  }

  Future<void> toggleConnection() async {
    if (_connectionState == VpnConnectionState.connected ||
        _connectionState == VpnConnectionState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    final target = _pickSmartConfig();
    if (target == null) {
      _addLog('ERROR: No configurations available to connect.');
      return;
    }

    _selectedConfigId = target.id;
    _connectionState = VpnConnectionState.connecting;
    _addLog('Connecting via ${target.protocolLabel}: ${target.name}...');
    notifyListeners();

    try {
      switch (target.protocol) {
        case VpnProtocol.v2ray:
          final granted = await _v2ray.requestPermission();
          if (!granted) throw Exception('VPN permission denied');
          await _v2ray.startV2Ray(
            remark: target.name,
            config: target.rawConfig,
            bypassSubnets: _bypassLan ? ['192.168.0.0/16', '10.0.0.0/8'] : [],
            notificationDisconnectButtonName: 'DISCONNECT',
          );
          break;

        case VpnProtocol.wireguard:
          await _wireGuard.startVpn(
            serverAddress: '${target.serverAddress}:${target.port}',
            wgQuickConfig: target.rawConfig,
            providerBundleIdentifier: 'com.vpnsopr.gaming',
          );
          break;

        case VpnProtocol.openvpn:
          final granted = await _openVpn.requestPermissionAndroid();
          if (!granted) throw Exception('OpenVPN permission denied');
          await _openVpn.connect(target.rawConfig, target.name);
          break;
      }
      _activePingMs = target.pingMs;
    } catch (e) {
      _addLog('Connection failed: $e');
      _setDisconnectedState();
    }
  }

  Future<void> disconnect() async {
    _connectionState = VpnConnectionState.disconnecting;
    notifyListeners();
    try {
      await _v2ray.stopV2Ray();
    } catch (_) {}
    try {
      await _wireGuard.stopVpn();
    } catch (_) {}
    try {
      await _openVpn.disconnect();
    } catch (_) {}
    _setDisconnectedState();
    _addLog('Disconnected.');
  }

  void _setConnectedState() {
    if (_connectionState == VpnConnectionState.connected) return;
    _connectionState = VpnConnectionState.connected;
    _connectedAt = DateTime.now();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null) {
        final diff = DateTime.now().difference(_connectedAt!);
        _duration = _formatDuration(diff);
        notifyListeners();
      }
    });
  }

  void _setDisconnectedState() {
    _connectionState = VpnConnectionState.disconnected;
    _durationTimer?.cancel();
    _connectedAt = null;
    _duration = '00:00:00';
    _uploadSpeed = '0 KB/s';
    _downloadSpeed = '0 KB/s';
    notifyListeners();
  }

  Future<int> importRawInput(String input, {String? customName}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 0;

    int added = 0;

    if (trimmed.contains('[Interface]') && trimmed.contains('[Peer]')) {
      final endpointMatch =
          RegExp(r'Endpoint\s*=\s*([^\s:]+):(\d+)').firstMatch(trimmed);
      final host = endpointMatch?.group(1) ?? 'wireguard.server';
      final port = int.tryParse(endpointMatch?.group(2) ?? '51820') ?? 51820;
      _configs.add(VpnConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: customName ?? 'WG $host',
        protocol: VpnProtocol.wireguard,
        rawConfig: trimmed,
        serverAddress: host,
        port: port,
        isUdpPreferred: true,
      ));
      added++;
    } else if (trimmed.contains('client') && trimmed.contains('remote ')) {
      final remoteMatch =
          RegExp(r'remote\s+([^\s]+)\s+(\d+)').firstMatch(trimmed);
      final host = remoteMatch?.group(1) ?? 'openvpn.server';
      final port = int.tryParse(remoteMatch?.group(2) ?? '1194') ?? 1194;
      _configs.add(VpnConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: customName ?? 'OVPN $host',
        protocol: VpnProtocol.openvpn,
        rawConfig: trimmed,
        serverAddress: host,
        port: port,
        isUdpPreferred: trimmed.contains('proto udp'),
      ));
      added++;
    } else if (trimmed.startsWith('{') && trimmed.contains('outbounds')) {
      _configs.add(VpnConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: customName ?? 'Xray JSON',
        protocol: VpnProtocol.v2ray,
        rawConfig: trimmed,
        serverAddress: 'json.xray',
        port: 443,
      ));
      added++;
    } else {
      final lines = trimmed.split(RegExp(r'\r?\n'));
      for (final line in lines) {
        final link = line.trim();
        if (link.isEmpty) continue;
        try {
          final parsed = FlutterV2ray.parseFromURL(link);
          final lower = link.toLowerCase();
          final udpFriendly =
              lower.contains('type=kcp') || lower.contains('type=quic');
          _configs.add(VpnConfig(
            id: '${DateTime.now().microsecondsSinceEpoch}_$added',
            name: customName ?? parsed.remark,
            protocol: VpnProtocol.v2ray,
            rawConfig: parsed.getFullConfiguration(),
            serverAddress: parsed.address,
            port: parsed.port,
            isUdpPreferred: udpFriendly,
          ));
          added++;
        } catch (e) {
          _addLog('Skipped invalid line: $e');
        }
      }
    }

    if (added > 0) {
      _selectedConfigId ??= _configs.first.id;
      await _saveConfigs();
      _addLog('Imported $added configuration(s).');
      notifyListeners();
    }
    return added;
  }

  Future<int> importSubscription(String url) async {
    _addLog('Fetching subscription: $url');
    final response = await http.get(Uri.parse(url.trim()));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    String body = response.body.trim();
    if (!body.contains('://')) {
      try {
        final normalized = base64.normalize(body);
        body = utf8.decode(base64Decode(normalized));
      } catch (_) {}
    }
    return importRawInput(body);
  }

  Future<int?> testPing(VpnConfig config) async {
    try {
      if (config.protocol == VpnProtocol.v2ray) {
        final delay = await _v2ray.getServerDelay(config: config.rawConfig);
        config.pingMs = delay > 0 ? delay : null;
      } else {
        final sw = Stopwatch()..start();
        final socket = await Socket.connect(
          config.serverAddress,
          config.port,
          timeout: const Duration(seconds: 3),
        );
        sw.stop();
        socket.destroy();
        config.pingMs = sw.elapsedMilliseconds;
      }
    } catch (_) {
      config.pingMs = -1;
    }
    await _saveConfigs();
    notifyListeners();
    return config.pingMs;
  }

  Future<void> testAllPings() async {
    for (final c in _configs) {
      await testPing(c);
    }
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void _addLog(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '[$ts] $message');
    if (_logs.length > 250) _logs.removeLast();
  }

  String _formatBytesPerSec(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
