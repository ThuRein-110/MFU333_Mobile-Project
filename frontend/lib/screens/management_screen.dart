import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api_service.dart';

class ManagementScreen extends StatefulWidget {
  final int index;
  final String title;
  const ManagementScreen({super.key, required this.index, required this.title});
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  bool loading = false, busy = false;
  String? error;
  List<dynamic> rows = [];
  final Map<int, String> registrationStatuses = <int, String>{};
  final search = TextEditingController();
  final activityId = TextEditingController();
  final qrToken = TextEditingController();
  final participantActivityId = TextEditingController();

  String get role => '${ApiService.currentUser?['role'] ?? ''}';
  String get path {
    switch (widget.index) {
      case 1:
      case 2:
        return '/api/activities';
      case 14:
        return '/api/admin/users';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    activityId.dispose();
    qrToken.dispose();
    participantActivityId.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (path.isEmpty) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await ApiService.request('GET', path);
      final d = ApiService.unwrap(r);
      rows = d is List ? d : [];

      if (role == 'student' && widget.index == 1) {
        final registrationResponse = await ApiService.request(
          'GET',
          '/api/registrations/my',
        );
        final registrationData = ApiService.unwrap(registrationResponse);
        registrationStatuses
          ..clear()
          ..addEntries(
            (registrationData is List ? registrationData : <dynamic>[])
                .whereType<Map>()
                .map((item) {
                  final id = int.tryParse('${item['activity_id']}');
                  final status =
                      '${item['registration_status'] ?? item['status'] ?? ''}';
                  return id == null ? null : MapEntry(id, status);
                })
                .whereType<MapEntry<int, String>>(),
          );
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> call(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    setState(() => busy = true);
    try {
      final r = await ApiService.request(method, url, body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r is Map
                ? context.tr('${r['message'] ?? 'ดำเนินการสำเร็จ'}')
                : context.tr('ดำเนินการสำเร็จ'),
          ),
        ),
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF102A4C),
                ),
              ),
            ),
            IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        if (loading) const LinearProgressIndicator(),
        if (error != null) _errorCard(),
        if (widget.index == 1) _activities(),
        if (widget.index == 2) _activityDetails(),
        if (widget.index == 3) _participants(),
        if (widget.index == 4) _scanner(),
        if (widget.index == 5) _qrManagement(),
        if (widget.index == 6) _qrCreatorPage(),
        if (widget.index == 7 ||
            widget.index == 8 ||
            widget.index == 9 ||
            widget.index == 10 ||
            widget.index == 11 ||
            widget.index == 12)
          _unsupported(),
        if (widget.index == 13) _points(),
        if (widget.index == 14) _users(),
      ],
    );
  }

  Widget _errorCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(context.tr(error!), style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: load, child: Text(context.tr('ลองอีกครั้ง'))),
        ],
      ),
    ),
  );

  Widget _activities() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: context.tr('ค้นหากิจกรรม'),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          if (role != 'student')
            FilledButton.icon(
              onPressed: _activityForm,
              icon: const Icon(Icons.add),
              label: Text(context.tr('เพิ่มกิจกรรม')),
            ),
        ],
      ),
      const SizedBox(height: 12),
      _dataTable(
        rows
            .where(
              (e) =>
                  search.text.isEmpty ||
                  '${e['title']}'.toLowerCase().contains(
                    search.text.toLowerCase(),
                  ),
            )
            .toList(),
        ['activity_id', 'title', 'location', 'status', 'points'],
        actions: true,
      ),
    ],
  );

  Widget _studentJoinButton(Map<String, dynamic> activity) {
    final id = int.tryParse('${activity['activity_id']}');
    final registrationStatus = id == null ? null : registrationStatuses[id];

    if (registrationStatus == 'attended') {
      return Text(
        context.tr('เช็กชื่อเข้าร่วมแล้ว'),
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
      );
    }

    if (registrationStatus == 'registered') {
      return OutlinedButton.icon(
        onPressed: busy || id == null
            ? null
            : () => _confirmCancelRegistration(id),
        icon: const Icon(Icons.event_busy, size: 18),
        label: Text(context.tr('ยกเลิกการเข้าร่วม')),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
      );
    }

    if ('${activity['status'] ?? ''}' != 'published') {
      return Text(
        context.tr('ยังไม่เปิดรับสมัคร'),
        style: TextStyle(color: Colors.grey),
      );
    }

    return FilledButton.tonal(
      onPressed: busy || id == null
          ? null
          : () => call('POST', '/api/registrations/$id'),
      child: Text(context.tr('เข้าร่วมกิจกรรม')),
    );
  }

  Future<void> _confirmCancelRegistration(int activityId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('ยืนยันยกเลิกการเข้าร่วม')),
        content: Text(
          context.tr('ต้องการยกเลิกการเข้าร่วมกิจกรรมนี้ใช่หรือไม่?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('ไม่ใช่')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('ยืนยันยกเลิก')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await call('DELETE', '/api/registrations/$activityId');
    }
  }

  Widget _dataTable(
    List<dynamic> data,
    List<String> keys, {
    bool actions = false,
  }) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Center(child: Text(context.tr('ไม่พบข้อมูลจาก Backend'))),
        ),
      );
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            ...keys.map((k) => DataColumn(label: Text(_label(k)))),
            if (actions) DataColumn(label: Text(context.tr('จัดการ'))),
          ],
          rows: data.whereType<Map>().map((raw) {
            final m = Map<String, dynamic>.from(raw);
            return DataRow(
              cells: [
                ...keys.map(
                  (k) => DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        ['status', 'role'].contains(k)
                            ? context.statusLabel(m[k])
                            : '${m[k] ?? '-'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                if (actions)
                  DataCell(
                    role == 'student'
                        ? _studentJoinButton(m)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: context.tr('แก้ไข'),
                                onPressed: () => _activityForm(existing: m),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                              ),
                              IconButton(
                                tooltip: context.tr('ยกเลิกกิจกรรม'),
                                onPressed: () => _confirmCancel(m),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _activityForm({Map<String, dynamic>? existing}) async {
    final fields = <String, TextEditingController>{
      'category_id': TextEditingController(
        text: '${existing?['category_id'] ?? ''}',
      ),
      'title': TextEditingController(text: '${existing?['title'] ?? ''}'),
      'location': TextEditingController(text: '${existing?['location'] ?? ''}'),
      'start_at': TextEditingController(text: '${existing?['start_at'] ?? ''}'),
      'end_at': TextEditingController(text: '${existing?['end_at'] ?? ''}'),
      'description': TextEditingController(
        text: '${existing?['description'] ?? ''}',
      ),
      'points': TextEditingController(text: '${existing?['points'] ?? 0}'),
      'zone_id': TextEditingController(text: '${existing?['zone_id'] ?? ''}'),
      'max_participants': TextEditingController(
        text: '${existing?['max_participants'] ?? ''}',
      ),
    };
    final formKey = GlobalKey<FormState>();
    String selectedStatus = '${existing?['status'] ?? 'draft'}';
    if (!['draft', 'published', 'cancelled'].contains(selectedStatus)) {
      selectedStatus = 'draft';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? context.tr('เพิ่มกิจกรรม')
                : context.tr('แก้ไขกิจกรรม'),
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('สถานะกิจกรรม'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text(
                            context.tr('ฉบับร่าง'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text(
                            context.tr('เผยแพร่ / เปิดรับสมัคร'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text(
                            context.tr('ยกเลิกกิจกรรม'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ...fields.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: TextFormField(
                          controller: e.value,
                          decoration: InputDecoration(
                            labelText: context.fieldLabel(e.key),
                          ),
                          validator: (v) =>
                              [
                                    'category_id',
                                    'title',
                                    'location',
                                    'start_at',
                                    'end_at',
                                  ].contains(e.key) &&
                                  (v == null || v.isEmpty)
                              ? context.tr('กรุณากรอกข้อมูล')
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('ยกเลิก')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: Text(context.tr('บันทึก')),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final body = <String, dynamic>{
        'category_id': int.tryParse(fields['category_id']!.text),
        'title': fields['title']!.text,
        'location': fields['location']!.text,
        'start_at': fields['start_at']!.text,
        'end_at': fields['end_at']!.text,
        'description': fields['description']!.text,
        'points': int.tryParse(fields['points']!.text) ?? 0,
        'zone_id': int.tryParse(fields['zone_id']!.text),
        'max_participants': int.tryParse(fields['max_participants']!.text),
        'status': selectedStatus,
      };
      if (existing == null) {
        await call('POST', '/api/activities', body: body);
      } else {
        await call(
          'PUT',
          '/api/activities/${existing['activity_id']}',
          body: body,
        );
      }
    }
    for (final c in fields.values) {
      c.dispose();
    }
  }

  Future<void> _confirmCancel(Map<String, dynamic> m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.tr('ยืนยันยกเลิกกิจกรรม')),
        content: Text(
          context.tr(
            'ต้องการยกเลิก "{title}" หรือไม่?',
            args: {'title': '${m['title']}'},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.tr('กลับ')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.tr('ยืนยัน')),
          ),
        ],
      ),
    );
    if (yes == true) {
      await call('DELETE', '/api/activities/${m['activity_id']}');
    }
  }

  Widget _activityDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr('รายละเอียดกิจกรรมจาก API /api/activities'),
        style: TextStyle(color: Colors.blueGrey),
      ),
      const SizedBox(height: 10),
      _dataTable(rows, [
        'activity_id',
        'title',
        'description',
        'start_at',
        'end_at',
        'status',
      ]),
    ],
  );

  Widget _participants() {
    if (role == 'student') {
      return FutureBuilder<dynamic>(
        future: ApiService.request('GET', '/api/registrations/my'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(context.tr(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = ApiService.unwrap(snapshot.data);
          final list = d is List ? d : <dynamic>[];
          if (list.isEmpty) {
            return Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(context.tr('ยังไม่มีรายการลงทะเบียน')),
              ),
            );
          }
          return Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(context.tr('กิจกรรม'))),
                  DataColumn(label: Text(context.tr('สถานะ'))),
                  DataColumn(label: Text(context.tr('จัดการ'))),
                ],
                rows: list.whereType<Map>().map((raw) {
                  final m = Map<String, dynamic>.from(raw);
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${m['title'] ?? m['activity_title'] ?? m['activity_id']}',
                        ),
                      ),
                      DataCell(
                        Text(
                          context.statusLabel(
                            m['registration_status'] ?? m['status'],
                          ),
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed:
                              (m['registration_status'] ?? m['status']) ==
                                  'registered'
                              ? () => call(
                                  'DELETE',
                                  '/api/registrations/${m['activity_id']}',
                                )
                              : null,
                          child: Text(context.tr('ยกเลิก')),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      );
    }
    final id = participantActivityId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('ค้นหาผู้ลงทะเบียนในกิจกรรม (Lecturer)'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: id,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('รหัสกิจกรรม')),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () async {
                if (id.text.trim().isEmpty) return;
                try {
                  final r = await ApiService.request(
                    'GET',
                    '/api/lecturer/activities/${id.text}/participants',
                  );
                  final d = ApiService.unwrap(r);
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(context.tr('รายชื่อผู้เข้าร่วม')),
                      content: SizedBox(
                        width: 600,
                        child: SingleChildScrollView(child: Text(d.toString())),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.tr('ปิด')),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr(e.toString()))),
                    );
                  }
                }
              },
              child: Text(context.tr('ดึงรายชื่อผู้ลงทะเบียน')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanner() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            context.tr('สแกน QR เพื่ออ่าน Token'),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                onDetect: (capture) {
                  if (capture.barcodes.isNotEmpty) {
                    final value = capture.barcodes.first.rawValue;
                    if (value != null && qrToken.text != value) {
                      setState(() => qrToken.text = value);
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activityId,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.tr('รหัสกิจกรรม')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: qrToken,
            decoration: InputDecoration(labelText: context.tr('QR Token')),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () {
                    call(
                      'POST',
                      '/api/checkins',
                      body: {
                        'activity_id': int.tryParse(activityId.text),
                        'token': qrToken.text.trim(),
                      },
                    );
                  },
            icon: const Icon(Icons.verified),
            label: Text(context.tr('ยืนยัน Check-in')),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Backend จะตรวจสอบ Campus Wi-Fi จาก IP ของคำขอจริง ไม่สามารถยืนยัน Wi-Fi จากหน้าจอแอปได้',
            ),
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _qrManagement() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF1265E8)),
          const SizedBox(height: 8),
          Text(
            context.tr('การจัดการ QR Code'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            context.tr(
              'Backend ปัจจุบันรองรับการสร้าง QR Token แต่ไม่มี API สำหรับดึงรายการ QR ทั้งหมด',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _qrCreator(),
            child: Text(context.tr('สร้าง QR Code')),
          ),
        ],
      ),
    ),
  );

  Widget _qrCreatorPage() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('สร้าง QR Code สำหรับกิจกรรม'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(context.tr('สร้าง QR Token ผ่าน Backend')),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : _qrCreator,
            icon: const Icon(Icons.qr_code),
            label: Text(context.tr('สร้าง QR Code')),
          ),
        ],
      ),
    ),
  );
  Future<void> _qrCreator() async {
    final id = TextEditingController();
    final start = TextEditingController();
    final end = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.tr('สร้าง QR Code')),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: id,
                decoration: InputDecoration(
                  labelText: context.tr('รหัสกิจกรรม'),
                ),
              ),
              TextField(
                controller: start,
                decoration: InputDecoration(
                  labelText: context.tr('เริ่มใช้งาน (ISO 8601)'),
                ),
              ),
              TextField(
                controller: end,
                decoration: InputDecoration(
                  labelText: context.tr('หมดอายุ (ISO 8601)'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(context.tr('ยกเลิก')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, {
              'id': id.text,
              'start': start.text,
              'end': end.text,
            }),
            child: Text(context.tr('สร้าง')),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        final r = await ApiService.request(
          'POST',
          '/api/qr/${result['id']}',
          body: {'starts_at': result['start'], 'expires_at': result['end']},
        );
        final d = ApiService.unwrap(r);
        if (!mounted) return;
        final token = d is Map ? '${d['token'] ?? d['qr_token'] ?? d}' : '$d';
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(context.tr('สร้าง QR สำเร็จ')),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(data: token, size: 220),
                  SelectableText(token, textAlign: TextAlign.center),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(context.tr('ปิด')),
              ),
            ],
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.tr(e.toString()))));
        }
      }
    }
    id.dispose();
    start.dispose();
    end.dispose();
  }

  Widget _unsupported() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.info_outline, size: 40, color: Colors.orange),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'ยังเชื่อมต่อ {section} ไม่ได้',
              args: {'section': widget.title},
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'ตรวจสอบ Backend ZIP แล้วไม่พบ Route สำหรับ CRUD หมวดหมู่, Network Zones หรือ Allowed IPs จึงแสดงสถานะตามจริงและไม่จำลองการบันทึก',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _points() => FutureBuilder<dynamic>(
    future: ApiService.request('GET', '/api/points/history'),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _unsupported();
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final d = ApiService.unwrap(snapshot.data);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('ประวัติคะแนนของบัญชีที่เข้าสู่ระบบ'),
            style: TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),
          _dataTable(d is List ? d : [], [
            'activity_title',
            'points',
            'created_at',
          ]),
        ],
      );
    },
  );

  Widget _users() {
    if (role != 'admin') return _unsupported();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('จัดการบัญชีผู้ใช้จาก /api/admin/users')),
        const SizedBox(height: 10),
        if (rows.isNotEmpty)
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(context.tr('รหัส'))),
                  DataColumn(label: Text(context.tr('ชื่อ'))),
                  DataColumn(label: Text(context.tr('อีเมล'))),
                  DataColumn(label: Text(context.fieldLabel('role'))),
                  DataColumn(label: Text(context.tr('สถานะ'))),
                  DataColumn(label: Text(context.tr('จัดการ'))),
                ],
                rows: rows.whereType<Map>().map((u) {
                  final m = Map<String, dynamic>.from(u);
                  final active = m['is_active'] == 1 || m['is_active'] == true;
                  return DataRow(
                    cells: [
                      DataCell(Text('${m['user_id']}')),
                      DataCell(Text('${m['full_name']}')),
                      DataCell(Text('${m['email']}')),
                      DataCell(Text(context.statusLabel(m['role']))),
                      DataCell(
                        Text(
                          active
                              ? context.tr('ใช้งาน')
                              : context.tr('ปิดใช้งาน'),
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed: () => call(
                            'PATCH',
                            '/api/admin/users/${m['user_id']}/status',
                            body: {'is_active': !active},
                          ),
                          child: Text(
                            active
                                ? context.tr('ปิดบัญชี')
                                : context.tr('เปิดบัญชี'),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        if (rows.isEmpty && !loading) Text(context.tr('ไม่มีข้อมูลผู้ใช้')),
      ],
    );
  }

  String _label(String s) => context.fieldLabel(s);
}
