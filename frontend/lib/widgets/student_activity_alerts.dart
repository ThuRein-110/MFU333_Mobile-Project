import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import 'activity_date_time_field.dart';

/// Poll the shared QR feed while the student is using the app. A per-account
/// cursor survives reloads on this device, so a dismissed alert stays dismissed.
class StudentActivityAlerts extends StatefulWidget {
  const StudentActivityAlerts({
    super.key,
    required this.onOpenActivity,
    this.automaticallyShow = true,
  });

  final ValueChanged<int> onOpenActivity;
  final bool automaticallyShow;

  @override
  State<StudentActivityAlerts> createState() => _StudentActivityAlertsState();
}

class _StudentActivityAlertsState extends State<StudentActivityAlerts>
    with WidgetsBindingObserver {
  Timer? _timer;
  late final String _userId;
  late final String? _session;
  int _seen = 0;
  bool _loading = false, _dialogOpen = false;
  List<Map<String, dynamic>> _alerts = [];
  String? _error;

  String get _preferenceKey => 'activity-alert-seen-$_userId';
  bool get _current =>
      mounted &&
      ApiService.token == _session &&
      '${ApiService.currentUser?['user_id']}' == _userId;

  @override
  void initState() {
    super.initState();
    _userId = '${ApiService.currentUser?['user_id']}';
    _session = ApiService.token;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StudentActivityAlerts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.automaticallyShow && widget.automaticallyShow) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh({bool showHistory = false}) async {
    if (!_current ||
        _loading ||
        _dialogOpen ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getInt(_preferenceKey) ?? 0;
      if (!mounted || !_current) return;
      final data = ApiService.unwrap(
        await ApiService.request('GET', '/api/qr/alerts'),
      );
      if (!mounted || !_current) return;
      setState(() {
        _seen = seen;
        _error = null;
        _alerts = (data is List ? data : <dynamic>[])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      });
      final fresh = _alerts.where((row) => _id(row) > _seen).toList();
      if (showHistory ||
          (widget.automaticallyShow &&
              fresh.isNotEmpty &&
              ModalRoute.of(context)?.isCurrent == true)) {
        await _show(showHistory ? _alerts : fresh);
      }
    } catch (error) {
      if (mounted && _current) {
        setState(() => _error = error.toString());
        if (showHistory) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.tr(_error!))));
        }
      }
    } finally {
      _loading = false;
    }
  }

  int _id(Map<String, dynamic> row) => int.tryParse('${row['qr_id']}') ?? 0;

  Future<void> _show(List<Map<String, dynamic>> rows) async {
    _dialogOpen = true;
    // One popup can announce several activities; multiple codes for the same
    // activity produce only one entry in that popup.
    final byActivity = <String, Map<String, dynamic>>{};
    int cursor = _seen;
    for (final row in rows) {
      byActivity.putIfAbsent('${row['activity_id']}', () => row);
      if (_id(row) > cursor) cursor = _id(row);
    }
    try {
      final selected = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('แจ้งเตือนกิจกรรมใหม่')),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      rows.isEmpty ? 'ยังไม่มีแจ้งเตือนกิจกรรมใหม่' : 'มีกิจกรรมเปิดใช้ QR แล้ว ดูรายละเอียดและลงทะเบียนก่อนเช็คอิน',
                    ),
                  ),
                  for (final row in byActivity.values) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${row['activity_title']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if ('${row['location'] ?? ''}'.isNotEmpty)
                      Text('${row['location']}'),
                    if (DateTime.tryParse('${row['starts_at']}')
                        case final DateTime start)
                      Text(
                        '${context.tr('เริ่มใช้งาน')}: ${formatActivityDateTime(context, start)}',
                      ),
                    if (DateTime.tryParse('${row['expires_at']}')
                        case final DateTime end)
                      Text(
                        '${context.tr('หมดอายุ')}: ${formatActivityDateTime(context, end)}',
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        int.parse('${row['activity_id']}'),
                      ),
                      child: Text(context.tr('ดูกิจกรรมนี้')),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('ปิด')),
            ),
          ],
        ),
      );
      if (!_current) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_preferenceKey, cursor);
      if (!_current) return;
      setState(() => _seen = cursor);
      if (selected != null) widget.onOpenActivity(selected);
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('student-activity-alerts'),
    tooltip: context.tr('แจ้งเตือนกิจกรรม'),
    onPressed: () => _refresh(showHistory: true),
    icon: Badge(
      isLabelVisible: _alerts.any((row) => _id(row) > _seen),
      child: Icon(
        _error == null
            ? Icons.notifications_none
            : Icons.notifications_outlined,
        color: const Color(0xFF52657A),
      ),
    ),
  );
}
