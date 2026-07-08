import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';

class DeliveryConfirmationResult {
  const DeliveryConfirmationResult({this.note});

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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final note = _noteController.text.trim();
    Navigator.pop(
      context,
      DeliveryConfirmationResult(note: note.isEmpty ? null : note),
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
                  'أضف ملاحظة التسليم لطلب ${widget.orderId}.',
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
                const SizedBox(height: 16),
                AppActionButton(
                  label: 'تأكيد',
                  icon: AppIcons.tick_circle,
                  onPressed: _confirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
