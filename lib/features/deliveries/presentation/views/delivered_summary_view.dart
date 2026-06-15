import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../domain/courier_order.dart';
import '../widgets/order_card.dart';
import 'order_details_view.dart';

enum DeliveredSummaryFilter { today, yesterday, week, month, custom }

extension DeliveredSummaryFilterLabel on DeliveredSummaryFilter {
  String get label {
    return switch (this) {
      DeliveredSummaryFilter.today => 'انهارده',
      DeliveredSummaryFilter.yesterday => 'امبارح',
      DeliveredSummaryFilter.week => 'الأسبوع ده',
      DeliveredSummaryFilter.month => 'الشهر ده',
      DeliveredSummaryFilter.custom => 'مخصص',
    };
  }
}

class DeliveredSummaryView extends StatefulWidget {
  const DeliveredSummaryView({super.key, required this.orders});

  final List<CourierOrder> orders;

  @override
  State<DeliveredSummaryView> createState() => _DeliveredSummaryViewState();
}

class _DeliveredSummaryViewState extends State<DeliveredSummaryView> {
  DeliveredSummaryFilter _selectedFilter = DeliveredSummaryFilter.today;
  DateTimeRange? _customRange;

  List<CourierOrder> get _filteredOrders {
    final range = _activeRange;
    return widget.orders.where((order) {
      final deliveredAt = order.deliveredAt;
      if (deliveredAt == null) return false;
      return !deliveredAt.isBefore(range.start) &&
          deliveredAt.isBefore(range.end);
    }).toList();
  }

  DateTimeRange get _activeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (_selectedFilter) {
      DeliveredSummaryFilter.today => DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      DeliveredSummaryFilter.yesterday => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
      DeliveredSummaryFilter.week => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today.add(const Duration(days: 1)),
      ),
      DeliveredSummaryFilter.month => DateTimeRange(
        start: DateTime(now.year, now.month),
        end: today.add(const Duration(days: 1)),
      ),
      DeliveredSummaryFilter.custom =>
        _customRange ??
            DateTimeRange(
              start: today,
              end: today.add(const Duration(days: 1)),
            ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;
    final totalValue = orders.fold<double>(
      0,
      (total, order) => total + order.total,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: orders.isEmpty ? 4 : orders.length + 3,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const PageTopBar(
                title: 'إجمالي التسليم',
                subtitle: 'ملخص الطلبات المسلّمة حسب الفترة',
                showBackButton: true,
              );
            }

            if (index == 1) {
              return _FilterBar(
                selectedFilter: _selectedFilter,
                customRange: _customRange,
                onChanged: _changeFilter,
              );
            }

            if (index == 2) {
              return _SummaryTotals(count: orders.length, total: totalValue);
            }

            if (orders.isEmpty) {
              return const _EmptySummaryState();
            }

            final order = orders[index - 3];
            return OrderCard(
              order: order,
              showDeliveredMeta: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => OrderDetailsView(order: order),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _changeFilter(DeliveredSummaryFilter filter) async {
    if (filter == DeliveredSummaryFilter.custom) {
      final pickedRange = await _pickCustomRange();

      if (pickedRange == null) return;
      setState(() {
        _selectedFilter = filter;
        _customRange = pickedRange;
      });
      return;
    }

    setState(() => _selectedFilter = filter);
  }

  Future<DateTimeRange?> _pickCustomRange() {
    final today = _dateOnly(DateTime.now());

    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomRangeSheet(
        firstDate: today.subtract(const Duration(days: 365)),
        lastDate: today,
        initialRange:
            _customRange ??
            DateTimeRange(
              start: today.subtract(const Duration(days: 6)),
              end: today.add(const Duration(days: 1)),
            ),
      ),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedFilter,
    required this.customRange,
    required this.onChanged,
  });

  final DeliveredSummaryFilter selectedFilter;
  final DateTimeRange? customRange;
  final ValueChanged<DeliveredSummaryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in DeliveredSummaryFilter.values) ...[
            ChoiceChip(
              label: Text(_labelFor(filter)),
              selected: selectedFilter == filter,
              onSelected: (_) => onChanged(filter),
              showCheckmark: false,
              selectedColor: AppColors.primary.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: selectedFilter == filter
                    ? AppColors.primary
                    : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w900,
              ),
              side: BorderSide(
                color: selectedFilter == filter
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _labelFor(DeliveredSummaryFilter filter) {
    if (filter != DeliveredSummaryFilter.custom || customRange == null) {
      return filter.label;
    }

    return _formatRange(
      customRange!.start,
      customRange!.end.subtract(const Duration(days: 1)),
    );
  }

  String _formatDay(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}';
  }

  String _formatRange(DateTime start, DateTime end) {
    return '\u2066${_formatDay(start)} - ${_formatDay(end)}\u2069';
  }
}

const double _sheetControlRadius = 18;
const double _sheetActionHeight = 54;
const double _wheelItemExtent = 44;
const double _wheelPickerHeight = 220;

class _CustomRangeSheet extends StatefulWidget {
  const _CustomRangeSheet({
    required this.firstDate,
    required this.lastDate,
    required this.initialRange,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange initialRange;

  @override
  State<_CustomRangeSheet> createState() => _CustomRangeSheetState();
}

class _CustomRangeSheetState extends State<_CustomRangeSheet> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = _dateOnly(widget.initialRange.start);
    _endDate = _dateOnly(
      widget.initialRange.end.subtract(const Duration(days: 1)),
    );
  }

  int get _selectedDays => _endDate.difference(_startDate).inDays + 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;
    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: outlineColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.10),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, 44),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_sheetControlRadius),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _DateSelectionCard(
                    label: 'من',
                    value: _formatDate(_startDate),
                    onTap: () => _pickDate(isStart: true),
                  ),
                  const SizedBox(height: 10),
                  _DateSelectionCard(
                    label: 'إلى',
                    value: _formatDate(_endDate),
                    onTap: () => _pickDate(isStart: false),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SelectedDaysSummary(days: _selectedDays),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetToDefault,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(_sheetActionHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _sheetControlRadius,
                          ),
                        ),
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Text('إعادة الضبط'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _applySelection,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(_sheetActionHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _sheetControlRadius,
                          ),
                        ),
                      ),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final currentDate = isStart ? _startDate : _endDate;
    final pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => _WheelDatePickerDialog(
        initialDate: currentDate,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
      ),
    );

    if (pickedDate == null) return;

    setState(() {
      final normalizedDate = _dateOnly(pickedDate);

      if (isStart) {
        _startDate = normalizedDate;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = normalizedDate;
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
      }
    });
  }

  void _resetToDefault() {
    _setRange(
      widget.lastDate.subtract(const Duration(days: 6)),
      widget.lastDate,
    );
  }

  void _setRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = _clampDate(_dateOnly(start));
      _endDate = _clampDate(_dateOnly(end));

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  void _applySelection() {
    Navigator.pop(
      context,
      DateTimeRange(
        start: _startDate,
        end: _endDate.add(const Duration(days: 1)),
      ),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _clampDate(DateTime value) {
    final firstDate = _dateOnly(widget.firstDate);
    final lastDate = _dateOnly(widget.lastDate);

    if (value.isBefore(firstDate)) return firstDate;
    if (value.isAfter(lastDate)) return lastDate;
    return value;
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }
}

class _DateSelectionCard extends StatelessWidget {
  const _DateSelectionCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardOutlineColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.10);
    final cardColor = isDark ? AppColors.darkCardColor : AppColors.lightSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_sheetControlRadius),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(_sheetControlRadius),
          border: Border.all(color: cardOutlineColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.18 : 0.09,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.18 : 0.08,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                AppIcons.calendar,
                size: 17,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDaysSummary extends StatelessWidget {
  const _SelectedDaysSummary({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(_sheetControlRadius),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.24 : 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.calendar, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'عدد الأيام المحددة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$days يوم',
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelColumnLabel extends StatelessWidget {
  const _WheelColumnLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: mutedColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WheelDivider extends StatelessWidget {
  const _WheelDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: color);
  }
}

class _WheelSelectionFrame extends StatelessWidget {
  const _WheelSelectionFrame({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: _wheelItemExtent + 8,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
        ),
      ),
    );
  }
}

class _WheelDatePickerDialog extends StatefulWidget {
  const _WheelDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_WheelDatePickerDialog> createState() => _WheelDatePickerDialogState();
}

class _WheelDatePickerDialogState extends State<_WheelDatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  DateTime get _selectedDate =>
      DateTime(_selectedYear, _selectedMonth, _selectedDay);

  List<int> get _years => [
    for (int year = widget.firstDate.year; year <= widget.lastDate.year; year++)
      year,
  ];

  List<int> get _months {
    final startMonth = _selectedYear == widget.firstDate.year
        ? widget.firstDate.month
        : 1;
    final endMonth = _selectedYear == widget.lastDate.year
        ? widget.lastDate.month
        : 12;

    return [for (int month = startMonth; month <= endMonth; month++) month];
  }

  List<int> get _days {
    final monthDays = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final startDay =
        _selectedYear == widget.firstDate.year &&
            _selectedMonth == widget.firstDate.month
        ? widget.firstDate.day
        : 1;
    final endDay =
        _selectedYear == widget.lastDate.year &&
            _selectedMonth == widget.lastDate.month
        ? widget.lastDate.day
        : monthDays;

    return [for (int day = startDay; day <= endDay; day++) day];
  }

  @override
  void initState() {
    super.initState();
    final initialDate = _normalize(widget.initialDate);
    _selectedYear = initialDate.year;
    _selectedMonth = initialDate.month;
    _selectedDay = initialDate.day;
    _dayController = FixedExtentScrollController(
      initialItem: _days.indexOf(_selectedDay),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _months.indexOf(_selectedMonth),
    );
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_selectedYear),
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;
    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : AppColors.lightSurface;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: outlineColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.22 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        AppIcons.calendar,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 58),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'اختيار التاريخ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatPreviewDate(_selectedDate),
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(44, 44),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: _wheelPickerHeight,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: outlineColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        const Expanded(child: _WheelColumnLabel('اليوم')),
                        _WheelDivider(color: outlineColor),
                        const Expanded(child: _WheelColumnLabel('الشهر')),
                        _WheelDivider(color: outlineColor),
                        const Expanded(child: _WheelColumnLabel('السنة')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _WheelPickerColumn(
                                values: _days,
                                controller: _dayController,
                                onSelectedItemChanged: _updateDay,
                                formatter: _formatTwoDigits,
                              ),
                            ),
                            _WheelDivider(color: outlineColor),
                            Expanded(
                              child: _WheelPickerColumn(
                                values: _months,
                                controller: _monthController,
                                onSelectedItemChanged: _updateMonth,
                                formatter: _formatTwoDigits,
                              ),
                            ),
                            _WheelDivider(color: outlineColor),
                            Expanded(
                              child: _WheelPickerColumn(
                                values: _years,
                                controller: _yearController,
                                onSelectedItemChanged: _updateYear,
                                formatter: (value) => '$value',
                              ),
                            ),
                          ],
                        ),
                        _WheelSelectionFrame(isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(_sheetActionHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _sheetControlRadius,
                        ),
                      ),
                      side: BorderSide(color: outlineColor),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedDate),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(_sheetActionHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _sheetControlRadius,
                        ),
                      ),
                    ),
                    child: const Text('تأكيد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateYear(int index) {
    setState(() {
      _selectedYear = _years[index];
      _selectedMonth = _clampValue(_selectedMonth, _months);
      _selectedDay = _clampValue(_selectedDay, _days);
    });
    _syncController(_monthController, _months.indexOf(_selectedMonth));
    _syncController(_dayController, _days.indexOf(_selectedDay));
  }

  void _updateMonth(int index) {
    setState(() {
      _selectedMonth = _months[index];
      _selectedDay = _clampValue(_selectedDay, _days);
    });
    _syncController(_dayController, _days.indexOf(_selectedDay));
  }

  void _updateDay(int index) {
    setState(() => _selectedDay = _days[index]);
  }

  int _clampValue(int value, List<int> values) {
    if (value < values.first) return values.first;
    if (value > values.last) return values.last;
    return value;
  }

  void _syncController(FixedExtentScrollController controller, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients || index < 0) return;
      controller.jumpToItem(index);
    });
  }

  DateTime _normalize(DateTime value) {
    final dateOnly = DateTime(value.year, value.month, value.day);
    final firstDate = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final lastDate = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );

    if (dateOnly.isBefore(firstDate)) return firstDate;
    if (dateOnly.isAfter(lastDate)) return lastDate;
    return dateOnly;
  }

  String _formatPreviewDate(DateTime value) {
    return '${_formatTwoDigits(value.day)}/${_formatTwoDigits(value.month)}/${value.year}';
  }

  String _formatTwoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _WheelPickerColumn extends StatelessWidget {
  const _WheelPickerColumn({
    required this.values,
    required this.controller,
    required this.onSelectedItemChanged,
    required this.formatter,
  });

  final List<int> values;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelectedItemChanged;
  final String Function(int value) formatter;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _wheelItemExtent,
      diameterRatio: 1.8,
      perspective: 0.002,
      squeeze: 0.96,
      useMagnifier: true,
      magnification: 1.08,
      overAndUnderCenterOpacity: 0.42,
      physics: const FixedExtentScrollPhysics(parent: BouncingScrollPhysics()),
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: values.length,
        builder: (context, index) {
          return Center(
            child: Text(
              formatter(values[index]),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryTotals extends StatelessWidget {
  const _SummaryTotals({required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              icon: AppIcons.tick_circle,
              label: 'عدد التسليم',
              value: '$count',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryMetric(
              icon: AppIcons.money_3,
              label: 'القيمة',
              value: AppCurrency.format(total),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySummaryState extends StatelessWidget {
  const _EmptySummaryState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
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
        children: [
          Icon(
            AppIcons.filter_search,
            size: 30,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'مفيش تسليم في الفترة دي',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
