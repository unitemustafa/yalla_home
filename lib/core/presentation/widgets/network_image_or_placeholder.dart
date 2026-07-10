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
    final value = url?.trim() ?? '';
    if (value.isEmpty) return _placeholder();

    return Image.network(
      value,
      key: imageKey,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Image.asset(
      placeholderAsset,
      key: placeholderKey,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
    );
  }
}
