import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pps_tablet/core/network/network_mode_config.dart';

class NetworkModeBottomSheet extends StatefulWidget {
  const NetworkModeBottomSheet({
    super.key,
    required this.selectedMode,
    required this.isSelectionLocked,
    required this.onSelectMode,
  });

  final NetworkMode selectedMode;
  final bool isSelectionLocked;
  final Future<void> Function(NetworkMode mode) onSelectMode;

  @override
  State<NetworkModeBottomSheet> createState() => _NetworkModeBottomSheetState();
}

class _NetworkModeBottomSheetState extends State<NetworkModeBottomSheet> {
  String _internalPing = '-';
  String _publicPing = '-';
  bool _isPinging = true;
  bool _isRequestInFlight = false;
  Timer? _autoRefreshTimer;
  DateTime? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    _loadPing(showLoading: true);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadPing(showLoading: false);
    });
  }

  Future<void> _loadPing({required bool showLoading}) async {
    if (!mounted) return;
    if (_isRequestInFlight) return;

    _isRequestInFlight = true;
    if (showLoading) {
      setState(() => _isPinging = true);
    }

    try {
      final results = await Future.wait([
        _httpPing(NetworkModeConfig.internalApiBaseUrl),
        _httpPing(NetworkModeConfig.publicApiBaseUrl),
      ]);

      if (!mounted) return;
      setState(() {
        _internalPing = results[0];
        _publicPing = results[1];
        _lastUpdatedAt = DateTime.now();
        if (showLoading) _isPinging = false;
      });
    } finally {
      _isRequestInFlight = false;
      if (showLoading && mounted) {
        setState(() => _isPinging = false);
      }
    }
  }

  String _modeText(NetworkMode mode) {
    switch (mode) {
      case NetworkMode.auto:
        return 'Auto (Prioritas Internal)';
      case NetworkMode.internal:
        return 'Internal';
      case NetworkMode.public:
        return 'Public';
    }
  }

  String _modeDescription(NetworkMode mode) {
    switch (mode) {
      case NetworkMode.auto:
        return 'Prioritaskan jaringan lokal, otomatis pindah ke public jika lokal lambat/tidak terjangkau';
      case NetworkMode.internal:
        return 'Pakai jaringan lokal perusahaan';
      case NetworkMode.public:
        return 'Pakai jaringan internet/public';
    }
  }

  String _pingLabel(NetworkMode mode) {
    switch (mode) {
      case NetworkMode.auto:
        if (NetworkModeConfig.autoResolvedMode == NetworkMode.public) {
          return 'Public: $_publicPing';
        }
        return 'Internal: $_internalPing';
      case NetworkMode.internal:
        return _internalPing;
      case NetworkMode.public:
        return _publicPing;
    }
  }

  bool _isUnreachable(String pingRaw) {
    final normalized = pingRaw.trim().toLowerCase();
    return normalized == 'timeout' || normalized == 'tidak terjangkau';
  }

  bool _canSelectMode(NetworkMode mode) {
    if (_isPinging) return false;

    switch (mode) {
      case NetworkMode.auto:
        return !_isUnreachable(_internalPing) || !_isUnreachable(_publicPing);
      case NetworkMode.internal:
        return !_isUnreachable(_internalPing);
      case NetworkMode.public:
        return !_isUnreachable(_publicPing);
    }
  }

  IconData _modeIcon(NetworkMode mode) {
    switch (mode) {
      case NetworkMode.auto:
        return Icons.auto_awesome_rounded;
      case NetworkMode.internal:
        return Icons.apartment_rounded;
      case NetworkMode.public:
        return Icons.public_rounded;
    }
  }

  _PingView _pingView(String value) {
    final normalized = value.trim().toLowerCase();
    final ms = int.tryParse(normalized.replaceAll(RegExp(r'[^0-9]'), ''));

    if (ms != null) {
      if (ms <= 80) {
        return const _PingView(
          text: 'Sangat Baik',
          icon: Icons.network_check_rounded,
          color: Color(0xFF0B6B3A),
          bgColor: Color(0xFFE9F7EF),
        );
      }
      if (ms <= 180) {
        return const _PingView(
          text: 'Stabil',
          icon: Icons.network_ping_rounded,
          color: Color(0xFF9A6700),
          bgColor: Color(0xFFFFF6E5),
        );
      }
      return const _PingView(
        text: 'Tinggi',
        icon: Icons.network_ping_rounded,
        color: Color(0xFFB42318),
        bgColor: Color(0xFFFFEDEC),
      );
    }

    if (normalized == 'timeout' || normalized == 'tidak terjangkau') {
      return const _PingView(
        text: 'Offline',
        icon: Icons.signal_wifi_off_rounded,
        color: Color(0xFFB42318),
        bgColor: Color(0xFFFFEDEC),
      );
    }

    return const _PingView(
      text: 'Unknown',
      icon: Icons.help_outline_rounded,
      color: Color(0xFF475467),
      bgColor: Color(0xFFF2F4F7),
    );
  }

  Future<String> _httpPing(String baseUrl) async {
    final raw = baseUrl.trim();
    if (raw.isEmpty) return 'URL belum diisi';

    final uri = _buildHealthUri(raw);
    if (uri == null || uri.host.isEmpty) return 'URL tidak valid';

    final sw = Stopwatch()..start();
    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 3));
      sw.stop();

      if (response.statusCode != 200) {
        return 'HTTP ${response.statusCode}';
      }

      if (!_isExpectedHealthResponse(response.body)) {
        return 'Respon tidak valid';
      }

      return '${sw.elapsedMilliseconds} ms';
    } on TimeoutException {
      return 'Timeout';
    } on SocketException {
      return 'Tidak terjangkau';
    } on http.ClientException {
      return 'Tidak terjangkau';
    } catch (_) {
      return 'Error';
    }
  }

  Uri? _buildHealthUri(String baseUrl) {
    try {
      final base = Uri.parse(baseUrl);
      final appId = (dotenv.env['APP_ID'] ?? 'mobile').trim();
      final healthPath = '/api/update/$appId/version';
      return base.resolve(healthPath);
    } catch (_) {
      return null;
    }
  }

  bool _isExpectedHealthResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return false;
      if (decoded['success'] != true) return false;
      return decoded.containsKey('data');
    } catch (_) {
      return false;
    }
  }

  String _lastUpdatedText() {
    final dt = _lastUpdatedAt;
    if (dt == null) return '-';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final baseText = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Color(0xFF175CD3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Konfigurasi Jaringan',
                        style: baseText.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF101828),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh ping',
                      icon: _isPinging
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      onPressed: _isPinging
                          ? null
                          : () => _loadPing(showLoading: true),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pilih mode koneksi',
                  style: baseText.labelMedium?.copyWith(
                    color: const Color(0xFF475467),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                ...const [
                  NetworkMode.auto,
                  NetworkMode.internal,
                  NetworkMode.public,
                ].map((mode) {
                  final pingRaw = _pingLabel(mode);
                  final pingView = _pingView(pingRaw);
                  final isSelected = mode == widget.selectedMode;
                  final canSelect = _canSelectMode(mode);
                  final isDisabled = widget.isSelectionLocked || !canSelect;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF5F8FF)
                          : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2E5AAC)
                            : const Color(0xFFD0D5DD),
                        width: isSelected ? 1.2 : 1,
                      ),
                    ),
                    child: Opacity(
                      opacity: isDisabled ? 0.55 : 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFEFF4FF),
                          child: Icon(
                            _modeIcon(mode),
                            color: const Color(0xFF175CD3),
                            size: 19,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _modeText(mode),
                                      style: baseText.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF101828),
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF4FF),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Aktif',
                                        style: baseText.labelSmall?.copyWith(
                                          color: const Color(0xFF175CD3),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          _modeDescription(mode),
                          style: baseText.bodySmall?.copyWith(
                            color: const Color(0xFF667085),
                            height: 1.35,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: pingView.bgColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                pingView.icon,
                                size: 14,
                                color: pingView.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                pingRaw,
                                style: TextStyle(
                                  color: pingView.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: false,
                        onTap: isDisabled
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                await widget.onSelectMode(mode);
                              },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PingView {
  const _PingView({
    required this.text,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color bgColor;
}
