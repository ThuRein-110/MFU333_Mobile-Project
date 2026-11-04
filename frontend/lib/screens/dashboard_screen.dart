import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  bool loading = true;
  String? error;
  dynamic data;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final role = ApiService.currentUser?['role'];
      final path = role == 'lecturer'
          ? '/api/lecturer/dashboard'
          : role == 'admin'
              ? '/api/admin/dashboard'
              : '/api/activities';
      final response = await ApiService.request('GET', path);
      data = ApiService.unwrap(response);
    } catch (e) { error = e.toString(); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) {
    final role = ApiService.currentUser?['role'];
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final stats = map['stats'] is Map ? Map<String, dynamic>.from(map['stats']) : map;
    final activities = data is List ? data as List : (map['activities'] is List ? map['activities'] as List : <dynamic>[]);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(22), children: [
        Text(role == 'admin' ? 'ภาพรวมระบบ' : role == 'lecturer' ? 'ภาพรวมอาจารย์' : 'กิจกรรมที่เปิดให้เข้าร่วม',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF102A4C))),
        const SizedBox(height: 5),
        const Text('ข้อมูลจาก MFU Campus Activity API'),
        const SizedBox(height: 18),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text(error!, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: load, child: const Text('ลองอีกครั้ง'))
        ]))),
        if (!loading && error == null && role != 'student') ...[
          Wrap(spacing: 12, runSpacing: 12, children: stats.entries.map((e) =>
            SizedBox(width: 205, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(_label(e.key), style: const TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 10), Text('${e.value}', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF1265E8)))]
            ))))).toList()),
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 20), const Text('กิจกรรมของฉัน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...activities.take(10).map((a) => _activityCard(a)),
          ] else
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(data.toString()))),
        ],
        if (!loading && error == null && role == 'student') ...[
          const Text('รายการกิจกรรม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...activities.map((a) => _activityCard(a)),
        ]
      ]),
    );
  }

  Widget _activityCard(dynamic a) {
    if (a is! Map) return const SizedBox.shrink();
    final m = Map<String, dynamic>.from(a);
    return Card(child: ListTile(
      leading: const CircleAvatar(backgroundColor: Color(0xFFE8F1FF), child: Icon(Icons.event, color: Color(0xFF1265E8))),
      title: Text('${m['title'] ?? 'กิจกรรม'}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${m['location'] ?? '-'}  •  ${m['status'] ?? '-'}'),
      trailing: Text('${m['points'] ?? 0} แต้ม'),
    ));
  }
  String _label(String key) => key.replaceAll('_', ' ').toUpperCase();
}
