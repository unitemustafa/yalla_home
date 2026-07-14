import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';

class DeliveryConfirmationResult {
  const DeliveryConfirmationResult({
    this.note,
    this.proofBytes,
    this.proofName,
  });

  final String? note;
  final List<int>? proofBytes;
  final String? proofName;
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
  final _imagePicker = ImagePicker();
  XFile? _proof;
  bool _readingProof = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLostProof());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_readingProof) return;
    setState(() => _readingProof = true);
    final note = _noteController.text.trim();
    final proof = _proof;
    List<int>? proofBytes;
    if (proof != null) {
      try {
        proofBytes = await proof.readAsBytes();
      } catch (_) {
        if (!mounted) return;
        setState(() => _readingProof = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قراءة صورة إثبات التسليم.')),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      DeliveryConfirmationResult(
        note: note.isEmpty ? null : note,
        proofBytes: proofBytes,
        proofName: proof?.name,
      ),
    );
  }

  Future<void> _takeProofPhoto() async {
    try {
      final proof = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || proof == null) return;
      setState(() => _proof = proof);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح الكاميرا. تحقق من الإذن وحاول مرة أخرى.'),
        ),
      );
    }
  }

  Future<void> _restoreLostProof() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      final files = response.files;
      if (!mounted || files == null || files.isEmpty) return;
      setState(() => _proof = files.first);
    } catch (_) {
      // The proof remains optional when Android cannot restore a camera result.
    }
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
                  'أضف صورة أو ملاحظة تسليم للطلب ${widget.orderId}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة التسليم (اختياري)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('delivery-proof-capture-button'),
                    onPressed: _readingProof ? null : _takeProofPhoto,
                    icon: Icon(
                      _proof == null
                          ? Icons.camera_alt_rounded
                          : Icons.check_circle_rounded,
                    ),
                    label: Text(
                      _proof == null
                          ? 'التقاط صورة إثبات التسليم'
                          : 'تم التقاط الصورة — إعادة الالتقاط',
                    ),
                  ),
                ),
                if (_proof != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: _readingProof
                          ? null
                          : () => setState(() => _proof = null),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('حذف الصورة'),
                    ),
                  ),
                const SizedBox(height: 16),
                AppActionButton(
                  label: _readingProof ? 'جاري التجهيز...' : 'تأكيد',
                  icon: AppIcons.tick_circle,
                  onPressed: _readingProof ? null : _confirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
