import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/presentation/widgets/network_image_or_placeholder.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../data/courier_orders_api.dart';
import '../../domain/courier_order.dart';
import '../widgets/delivery_confirmation_sheet.dart';

typedef OrderPickedUpHandler = Future<CourierOrder> Function(String orderId);
typedef OrderDeliveredHandler =
    Future<CourierOrder> Function(
      String orderId,
      DeliveryConfirmationResult result,
    );

enum _SubmittingOrderAction { pickup, delivery }

class OrderDetailsView extends StatefulWidget {
  const OrderDetailsView({
    super.key,
    required this.order,
    this.onPickedUp,
    this.onDelivered,
  });

  final CourierOrder order;
  final OrderPickedUpHandler? onPickedUp;
  final OrderDeliveredHandler? onDelivered;

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  final _api = const CourierOrdersApi();
  late CourierOrder _order = widget.order;
  bool _loading = true;
  String? _error;
  _SubmittingOrderAction? _submittingAction;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await _api.loadOrder(widget.order.id);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openWhatsAppChat(BuildContext context) async {
    final phone = _order.phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.https('wa.me', '/$phone');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      if (!context.mounted) return;
      _showMessage('تعذر فتح واتساب على هذا الجهاز.');
    }
  }

  Future<void> _callCustomer(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: _order.phone);
    if (!await canLaunchUrl(uri)) {
      if (!context.mounted) return;
      _showMessage('المكالمات غير مدعومة على هذا الجهاز.');
      return;
    }
    await launchUrl(uri);
  }

  void _showContactOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ContactOptionsSheet(
          onWhatsApp: () {
            Navigator.pop(sheetContext);
            _openWhatsAppChat(context);
          },
          onPhoneCall: () {
            Navigator.pop(sheetContext);
            _callCustomer(context);
          },
        );
      },
    );
  }

  Future<void> _markPickedUp() async {
    if (_submittingAction != null || !_order.canMarkPickedUp) return;

    setState(() => _submittingAction = _SubmittingOrderAction.pickup);
    try {
      final handler = widget.onPickedUp ?? _api.markPickedUp;
      final updated = await handler(_order.id);
      if (!mounted) return;
      setState(() => _order = updated);
      _showMessage('تم تسجيل الاستلام بنجاح.');
    } catch (error) {
      if (!mounted) return;
      CustomSnackBar.showError(context: context, title: error.toString());
    } finally {
      if (mounted) setState(() => _submittingAction = null);
    }
  }

  Future<void> _confirmDelivery() async {
    if (_submittingAction != null || !_order.canMarkDelivered) return;

    final result = await showModalBottomSheet<DeliveryConfirmationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeliveryConfirmationSheet(orderId: _order.id),
    );

    if (!mounted || result == null) return;
    setState(() => _submittingAction = _SubmittingOrderAction.delivery);
    try {
      final handler =
          widget.onDelivered ??
          (String orderId, DeliveryConfirmationResult result) {
            return _api.markDelivered(orderId, note: result.note);
          };
      final updated = await handler(_order.id, result);
      if (!mounted) return;
      setState(() => _order = updated);
    } catch (error) {
      if (!mounted) return;
      CustomSnackBar.showError(context: context, title: error.toString());
      return;
    } finally {
      if (mounted) setState(() => _submittingAction = null);
    }
    if (!mounted) return;
    _showMessage('تم تسجيل التسليم بنجاح.');
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    CustomSnackBar.showInfo(context: context, title: message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = _order;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.58);

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _DetailRetryState(error: _error!, onRetry: _loadDetails)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  PageTopBar(
                    title: 'تفاصيل الطلب',
                    subtitle: order.id,
                    showBackButton: true,
                  ),
                  const SizedBox(height: 14),
                  _OrderHeader(order: order, mutedColor: mutedColor),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'بيانات العميل',
                    children: [
                      _CustomerSummaryTile(
                        order: order,
                        mutedColor: mutedColor,
                      ),
                      if (order.addressLabel != null)
                        _DetailRow(
                          icon: AppIcons.location,
                          label: 'اسم العنوان',
                          value: order.addressLabel!,
                          mutedColor: mutedColor,
                        ),
                      _DetailRow(
                        icon: AppIcons.location,
                        label: 'العنوان',
                        value: order.address,
                        mutedColor: mutedColor,
                        copyable: true,
                      ),
                      if (order.deliveryAreaName != null)
                        _DetailRow(
                          icon: AppIcons.location,
                          label: 'المنطقة',
                          value: order.deliveryAreaName!,
                          mutedColor: mutedColor,
                        ),
                      if (order.serviceCityName != null)
                        _DetailRow(
                          icon: AppIcons.location,
                          label: 'المدينة',
                          value: order.serviceCityName!,
                          mutedColor: mutedColor,
                        ),
                      _DetailRow(
                        icon: AppIcons.shopping_bag,
                        label: 'المحل',
                        value: order.marketSummary,
                        mutedColor: mutedColor,
                      ),
                      if (order.marketCount > 1)
                        _DetailRow(
                          icon: AppIcons.box,
                          label: 'عدد المحلات',
                          value: '${order.marketCount}',
                          mutedColor: mutedColor,
                        ),
                      if (order.customerNotes != null)
                        _DetailRow(
                          icon: AppIcons.document_text,
                          label: 'ملاحظة العميل',
                          value: order.customerNotes!,
                          mutedColor: mutedColor,
                          copyable: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'المنتجات',
                    children: order.items.isEmpty
                        ? [
                            Text(
                              'لا توجد منتجات في هذا الطلب.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: mutedColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ]
                        : [
                            for (final item in order.items)
                              _ProductRow(item: item),
                          ],
                  ),
                  if (order.isDelivered) ...[
                    const SizedBox(height: 12),
                    _DeliveryProofCard(order: order, mutedColor: mutedColor),
                  ],
                  const SizedBox(height: 16),
                  if (order.phone.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showContactOptions(context),
                            icon: const Icon(AppIcons.call, size: 18),
                            label: const Text('تواصل'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(AppIcons.routing, size: 18),
                            label: const Text('الخريطة'),
                          ),
                        ),
                      ],
                    ),
                  if (order.canMarkPickedUp || order.canMarkDelivered) ...[
                    const SizedBox(height: 12),
                    _LifecycleActions(
                      order: order,
                      submittingAction: _submittingAction,
                      onPickupPressed: _markPickedUp,
                      onDeliveryPressed: _confirmDelivery,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _DetailRetryState extends StatelessWidget {
  const _DetailRetryState({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifecycleActions extends StatelessWidget {
  const _LifecycleActions({
    required this.order,
    required this.submittingAction,
    required this.onPickupPressed,
    required this.onDeliveryPressed,
  });

  final CourierOrder order;
  final _SubmittingOrderAction? submittingAction;
  final VoidCallback onPickupPressed;
  final VoidCallback onDeliveryPressed;

  @override
  Widget build(BuildContext context) {
    final isUpdating = submittingAction != null;
    final pickupCompleted =
        order.status == CourierOrderStatus.pickedUp || order.isDelivered;

    return Column(
      children: [
        AppActionButton(
          label: 'تم الاستلام',
          icon: pickupCompleted ? AppIcons.tick_circle : AppIcons.box,
          variant: pickupCompleted
              ? AppActionButtonVariant.outlined
              : AppActionButtonVariant.filled,
          isLoading: submittingAction == _SubmittingOrderAction.pickup,
          onPressed: !isUpdating && order.canMarkPickedUp
              ? onPickupPressed
              : null,
        ),
        const SizedBox(height: 10),
        AppActionButton(
          label: 'تم التسليم',
          icon: AppIcons.tick_circle,
          isLoading: submittingAction == _SubmittingOrderAction.delivery,
          onPressed: !isUpdating && order.canMarkDelivered
              ? onDeliveryPressed
              : null,
        ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: order.status.color.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(AppIcons.box, color: order.status.color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.status.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: order.status.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${order.area} • ${AppCurrency.format(order.total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (order.isDelivered)
            Text(
              _formatTime(order.deliveredAt),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '---';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CustomerSummaryTile extends StatelessWidget {
  const _CustomerSummaryTile({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.10 : 0.045),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _CustomerAvatar(order: order, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      order.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.order, this.size = 46});

  final CourierOrder order;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = order.customerAvatarUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: NetworkImageOrPlaceholder(
        url: avatarUrl,
        placeholderAsset: AppAssets.defaultUserAvatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'صورة العميل',
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.mutedColor,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color mutedColor;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: copyable ? () => _copyValue(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: copyable ? 4 : 0,
              vertical: copyable ? 4 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: mutedColor),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  Icon(AppIcons.copy, size: 16, color: mutedColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyValue(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    CustomSnackBar.showSuccess(context: context, title: 'تم نسخ $label');
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.item});

  final CourierOrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'x${item.quantity}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppCurrency.format(item.total),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                AppCurrency.format(item.price),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryProofCard extends StatelessWidget {
  const _DeliveryProofCard({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final proof = order.deliveryProof;
    final proofUrl = order.deliveryProofUrl;

    return _SectionCard(
      title: 'إثبات التسليم',
      children: [
        _DetailRow(
          icon: AppIcons.calendar,
          label: 'وقت التسليم',
          value: _formatDateTime(order.deliveredAt),
          mutedColor: mutedColor,
        ),
        if (order.deliveryNote != null)
          _DetailRow(
            icon: AppIcons.document_text,
            label: 'ملاحظة',
            value: order.deliveryNote!,
            mutedColor: mutedColor,
          ),
        if (proof == null && proofUrl == null)
          Text(
            'لا توجد صورة مرفوعة.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w800,
            ),
          )
        else if (proofUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NetworkImageOrPlaceholder(
              url: proofUrl,
              placeholderAsset: AppAssets.defaultProduct,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 160,
              semanticLabel: 'صورة المنتج',
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              proof!.bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 160,
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '---';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _ContactOptionsSheet extends StatelessWidget {
  const _ContactOptionsSheet({
    required this.onWhatsApp,
    required this.onPhoneCall,
  });

  final VoidCallback onWhatsApp;
  final VoidCallback onPhoneCall;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'تواصل مع العميل',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _ContactOptionTile(
              icon: Icons.chat_rounded,
              iconColor: AppColors.success,
              title: 'شات واتساب',
              subtitle: 'فتح محادثة واتساب مع العميل',
              onTap: onWhatsApp,
            ),
            const SizedBox(height: 10),
            _ContactOptionTile(
              icon: AppIcons.call,
              iconColor: AppColors.primary,
              title: 'مكالمة هاتفية',
              subtitle: 'فتح تطبيق الهاتف للاتصال بالعميل',
              onTap: onPhoneCall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactOptionTile extends StatelessWidget {
  const _ContactOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: mutedColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
