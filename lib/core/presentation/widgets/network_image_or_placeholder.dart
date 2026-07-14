import 'package:flutter/material.dart';

/// Displays a local frontend fallback when an API image is absent or fails.
/// The fallback path is used only by the UI and is never written to an API model.
class NetworkImageOrPlaceholder extends StatelessWidget {
  const NetworkImageOrPlaceholder({
    super.key,
    required this.url,
    required this.placeholderAsset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.imageKey,
    this.placeholderKey,
  });

  final String? url;
  final String placeholderAsset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;
  final Key? imageKey;
  final Key? placeholderKey;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = _cacheExtent(width, devicePixelRatio);
    final cacheHeight = _cacheExtent(height, devicePixelRatio);
    final value = url?.trim() ?? '';
    if (value.isEmpty) return _placeholder(cacheWidth, cacheHeight);

    return Image.network(
      value,
      key: imageKey,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (_, _, _) => _placeholder(cacheWidth, cacheHeight),
    );
  }

  int? _cacheExtent(double? logicalExtent, double devicePixelRatio) {
    if (logicalExtent == null ||
        !logicalExtent.isFinite ||
        logicalExtent <= 0) {
      return null;
    }
    final physicalExtent = (logicalExtent * devicePixelRatio).round();
    return physicalExtent < 1 ? 1 : physicalExtent;
  }

  Widget _placeholder(int? cacheWidth, int? cacheHeight) {
    return Image.asset(
      placeholderAsset,
      key: placeholderKey,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }
}
