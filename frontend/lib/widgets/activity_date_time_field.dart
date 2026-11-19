import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

String formatActivityDateTime(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatShortDate(local)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

/// Displays local time while keeping the API value unambiguous and in UTC.
class ActivityDateTimeField extends StatefulWidget {
  const ActivityDateTimeField({
    super.key,
    required this.controller,
    required this.label,
    this.after,
  });

  final TextEditingController controller;
  final TextEditingController? after;
  final String label;

  @override
  State<ActivityDateTimeField> createState() => _ActivityDateTimeFieldState();
}

class _ActivityDateTimeFieldState extends State<ActivityDateTimeField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.after?.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant ActivityDateTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (oldWidget.after != widget.after) {
      oldWidget.after?.removeListener(_changed);
      widget.after?.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.after?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _pick() async {
    var initial =
        DateTime.tryParse(widget.controller.text)?.toLocal() ?? DateTime.now();
    if (initial.year < 2000 || initial.year > 2100) initial = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    widget.controller.text = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc().toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final date = DateTime.tryParse(widget.controller.text);
    return TextFormField(
      key: ValueKey('${widget.controller.text}-${widget.after?.text}-$locale'),
      initialValue: date == null ? '' : formatActivityDateTime(context, date),
      readOnly: true,
      onTap: _pick,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: context.tr('เลือกวันและเวลา'),
          icon: const Icon(Icons.calendar_month),
          onPressed: _pick,
        ),
      ),
      validator: (_) {
        final value = DateTime.tryParse(widget.controller.text);
        if (value == null) return context.tr('กรุณาเลือกวันและเวลา');
        final start = DateTime.tryParse(widget.after?.text ?? '');
        if (start != null && !value.isAfter(start)) {
          return context.tr('เวลาสิ้นสุดต้องอยู่หลังเวลาเริ่มต้น');
        }
        return null;
      },
    );
  }
}
