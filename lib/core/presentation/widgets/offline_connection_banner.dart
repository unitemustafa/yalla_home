import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class OfflineConnectionBanner extends StatefulWidget {
  const OfflineConnectionBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineConnectionBanner> createState() =>
      _OfflineConnectionBannerState();
}

class _OfflineConnectionBannerState extends State<OfflineConnectionBanner> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;
  bool _hasConnectivityState = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentConnection();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionState,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkCurrentConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionState(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasConnectivityState = true);
    }
  }

  void _updateConnectionState(List<ConnectivityResult> result) {
    final isOffline =
        result.isEmpty ||
        result.every((connection) => connection == ConnectivityResult.none);

    if (!mounted) return;
    if (_hasConnectivityState && _isOffline == isOffline) return;

    setState(() {
      _hasConnectivityState = true;
      _isOffline = isOffline;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              ignoring: !_isOffline,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _hasConnectivityState && _isOffline
                    ? const _OfflineBannerContent()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineBannerContent extends StatelessWidget {
  const _OfflineBannerContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('offline-connection-banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا يوجد اتصال بالإنترنت. تحقق من الشبكة لإكمال التحديثات.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ) ??
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
