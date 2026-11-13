import 'dart:convert';

enum VpnProtocol { wireguard, v2ray, openvpn }

enum RoutingMode { gaming, web, manual }

class VpnConfig {
  final String id;
  final String name;
  final VpnProtocol protocol;
  final String rawConfig;
  final String serverAddress;
  final int port;
  final bool isUdpPreferred;
  int? pingMs;

  VpnConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.rawConfig,
    required this.serverAddress,
    required this.port,
    this.isUdpPreferred = false,
    this.pingMs,
  });

  String get protocolLabel {
    switch (protocol) {
      case VpnProtocol.wireguard:
        return 'WireGuard';
      case VpnProtocol.v2ray:
        return 'V2Ray / Xray';
      case VpnProtocol.openvpn:
        return 'OpenVPN';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'rawConfig': rawConfig,
        'serverAddress': serverAddress,
        'port': port,
        'isUdpPreferred': isUdpPreferred,
        'pingMs': pingMs,
      };

  factory VpnConfig.fromJson(Map<String, dynamic> json) => VpnConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        protocol: VpnProtocol.values.firstWhere(
          (e) => e.name == json['protocol'],
          orElse: () => VpnProtocol.v2ray,
        ),
        rawConfig: json['rawConfig'] as String,
        serverAddress: json['serverAddress'] as String? ?? 'unknown',
        port: json['port'] as int? ?? 443,
        isUdpPreferred: json['isUdpPreferred'] as bool? ?? false,
        pingMs: json['pingMs'] as int?,
      );

  static String encodeList(List<VpnConfig> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<VpnConfig> decodeList(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((e) => VpnConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
