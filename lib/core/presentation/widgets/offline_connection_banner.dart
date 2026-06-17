import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../connectivity/internet_status_controller.dart';

class OfflineConnectionBanner extends StatefulWidget {
  const OfflineConnectionBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineConnectionBanner> createState() =>
      _OfflineConnectionBannerState();
}

class _OfflineConnectionBannerState extends State<OfflineConnectionBanner> {
  late final InternetStatusController _internetStatusController;

  @override
  void initState() {
    super.initState();
    _internetStatusController = InternetStatusController();
    unawaited(_internetStatusController.start());
  }

  @override
  void dispose() {
    _internetStatusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InternetStatusScope(
      controller: _internetStatusController,
      child: AnimatedBuilder(
        animation: _internetStatusController,
        builder: (context, _) {
          final isOffline = _internetStatusController.isOffline;

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
                    ignoring: !isOffline,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: isOffline
                          ? const _OfflineBannerContent()
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
