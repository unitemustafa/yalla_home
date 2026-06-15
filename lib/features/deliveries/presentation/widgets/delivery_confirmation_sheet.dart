import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../domain/courier_order.dart';

class DeliveryConfirmationResult {
  const DeliveryConfirmationResult({this.proof, this.note});

  final DeliveryProof? proof;
  final String? note;
}

class DeliveryConfirmationSheet extends StatefulWidget {
  const DeliveryConfirmationSheet({super.key, required this.orderId});

  final String orderId;

  @override
  State<DeliveryConfirmationSheet> createState() =>
      _DeliveryConfirmationSheetState();
}

class _DeliveryConfirmationSheetState extends State<DeliveryConfirmationSheet> {
  final _noteController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _pickedFile;
  Uint8List? _previewBytes;
  bool _isPicking = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isPicking = true);
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedFile = file;
        _previewBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      CustomSnackBar.showError(
        context: context,
        title: 'تعذر اختيار الصورة، حاول مرة أخرى.',
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _confirm() async {
    final file = _pickedFile;
    final bytes = _previewBytes;
    final proof = file != null && bytes != null
        ? DeliveryProof(fileName: file.name, bytes: bytes)
        : null;

    Navigator.pop(
      context,
      DeliveryConfirmationResult(
        proof: proof,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF222326) : Colors.white;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.58);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: mutedColor.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'تأكيد التسليم',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'ارفع صورة توقيع العميل أو إثبات التسليم لطلب ${widget.orderId}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _ProofPicker(
                  bytes: _previewBytes,
                  mutedColor: mutedColor,
                  isPicking: _isPicking,
                  onCameraPressed: () => _pickImage(ImageSource.camera),
                  onGalleryPressed: () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة اختيارية',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                AppActionButton(
                  label: 'تأكيد',
                  icon: AppIcons.tick_circle,
                  onPressed: _isPicking ? null : _confirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProofPicker extends StatelessWidget {
  const _ProofPicker({
    required this.bytes,
    required this.mutedColor,
    required this.isPicking,
    required this.onCameraPressed,
    required this.onGalleryPressed,
  });

  final Uint8List? bytes;
  final Color mutedColor;
  final bool isPicking;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        color: AppColors.primary.withValues(alpha: 0.04),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                ),
                child: bytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AppIcons.image, color: mutedColor, size: 30),
                          const SizedBox(height: 8),
                          Text(
                            'لا توجد صورة مرفوعة',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: mutedColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      )
                    : Image.memory(bytes!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isPicking ? null : onCameraPressed,
                  icon: const Icon(AppIcons.camera, size: 18),
                  label: const Text('كاميرا'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isPicking ? null : onGalleryPressed,
                  icon: const Icon(AppIcons.image, size: 18),
                  label: const Text('المعرض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
