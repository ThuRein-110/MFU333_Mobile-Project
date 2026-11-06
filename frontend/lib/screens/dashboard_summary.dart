import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';

class DashboardSummary extends StatelessWidget {
  const DashboardSummary({super.key, required this.role, required this.data});

  final String role;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final metrics = role == 'admin'
        ? _adminMetrics()
        : _lecturerMetrics(_map(data['stats']));
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                height: role == 'admin' ? 288 : 156,
                child: _card(context, metric),
              ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, _Metric metric) => Card(
    key: ValueKey('dashboard-metric-${metric.id}'),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: const Color(0xFF1265E8), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(metric.label),
                  style: const TextStyle(
                    color: Color(0xFF52657A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _format(metric.value),
            key: ValueKey('dashboard-value-${metric.id}'),
            style: const TextStyle(
              fontSize: 36,
              height: 1.2,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1265E8),
            ),
          ),
          const Spacer(),
          for (final detail in metric.details)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr(detail.label),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF52657A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _format(detail.value),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF102A4C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (metric.caption != null)
            Text(
              context.tr(metric.caption!),
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
        ],
      ),
    ),
  );

  List<_Metric> _adminMetrics() {
    final users = _map(data['users']);
    final activities = _map(data['activities']);
    final checkins = _map(data['checkins']);
    final points = _map(data['points']);
    return [
      _Metric(
        'users',
        'ผู้ใช้ทั้งหมด',
        _number(users['total_users']),
        Icons.people_outline,
        details: [
          _Detail('นักศึกษา', _number(users['total_students'])),
          _Detail('อาจารย์', _number(users['total_lecturers'])),
          _Detail('ผู้ดูแลระบบ', _number(users['total_admins'])),
          _Detail('บัญชีที่ใช้งาน', _number(users['active_users'])),
        ],
      ),
      _Metric(
        'activities',
        'กิจกรรมทั้งหมด',
        _number(activities['total_activities']),
        Icons.event_note,
        details: [
          _Detail('ฉบับร่าง', _number(activities['draft_activities'])),
          _Detail('เผยแพร่แล้ว', _number(activities['published_activities'])),
          _Detail('กำลังดำเนินการ', _number(activities['ongoing_activities'])),
          _Detail('เสร็จสิ้น', _number(activities['completed_activities'])),
          _Detail('ยกเลิกแล้ว', _number(activities['cancelled_activities'])),
        ],
      ),
      _Metric(
        'checkins',
        'การเช็คอินทั้งหมด',
        _number(checkins['total_checkins']),
        Icons.qr_code_scanner,
        details: [
          _Detail('ยืนยันสำเร็จ', _number(checkins['successful_checkins'])),
          _Detail('ถูกปฏิเสธ', _number(checkins['rejected_checkins'])),
        ],
      ),
      _Metric(
        'points',
        'คะแนนที่มอบแล้ว',
        _number(points['total_points_awarded']),
        Icons.stars_outlined,
        caption: 'คะแนนรวมที่มอบให้ผู้เข้าร่วมกิจกรรม',
      ),
    ];
  }

  List<_Metric> _lecturerMetrics(Map<String, dynamic> stats) => [
    _Metric(
      'activities',
      'กิจกรรมทั้งหมด',
      _number(stats['total_activities']),
      Icons.event_note,
    ),
    _Metric(
      'published',
      'เผยแพร่แล้ว',
      _number(stats['published_activities']),
      Icons.event_available,
    ),
    _Metric(
      'ongoing',
      'กำลังดำเนินการ',
      _number(stats['ongoing_activities']),
      Icons.schedule,
    ),
    _Metric(
      'completed',
      'เสร็จสิ้น',
      _number(stats['completed_activities']),
      Icons.task_alt,
    ),
    _Metric(
      'cancelled',
      'ยกเลิกแล้ว',
      _number(stats['cancelled_activities']),
      Icons.event_busy,
    ),
  ];

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  num _number(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

  String _format(num value) =>
      NumberFormat.decimalPattern('en_US').format(value);
}

class _Metric {
  const _Metric(
    this.id,
    this.label,
    this.value,
    this.icon, {
    this.details = const [],
    this.caption,
  });

  final String id;
  final String label;
  final num value;
  final IconData icon;
  final List<_Detail> details;
  final String? caption;
}

class _Detail {
  const _Detail(this.label, this.value);

  final String label;
  final num value;
}
