import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';

import '../services/api_service.dart';
import '../navigation/app_navigation.dart';
import 'activity_tool_screen.dart';
import 'system_settings_screen.dart';
import '../widgets/activity_date_time_field.dart';
import '../widgets/activity_cover_image.dart';

class ManagementScreen extends StatefulWidget {
  final int index;
  final String title;
  final int? activityId;
  final void Function(AppPage page, int? activityId)? onNavigate;
  const ManagementScreen({
    super.key,
    required this.index,
    required this.title,
    this.activityId,
    this.onNavigate,
  });
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  bool loading = false, busy = false;
  String? error;
  List<dynamic> rows = [];
  final Map<int, String> registrationStatuses = <int, String>{};
  final search = TextEditingController();
  num totalPoints = 0;
  String? loadedRole;
  int loadVersion = 0;

  AppNavigation get navigation =>
      AppNavigation(ApiService.currentUser?['role']?.toString());
  String get role => navigation.role;
  String get path {
    switch (widget.index) {
      case 1:
        return '/api/activities';
      case 2:
        return widget.activityId == null
            ? '/api/activities'
            : '/api/activities/${widget.activityId}';
      case 3:
        return navigation.isStudent ? '/api/registrations/my' : '';
      case 13:
        return '/api/points/history';
      case 14:
        return '/api/admin/users';
      case 17:
        return navigation.isAdmin
            ? '/api/admin/users?role=student'
            : navigation.isLecturer
            ? '/api/lecturer/students'
            : '';
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
  void didUpdateWidget(covariant ManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index ||
        oldWidget.activityId != widget.activityId ||
        loadedRole != role) {
      load();
    }
  }

  @override
  void dispose() {
    loadVersion++;
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final version = ++loadVersion;
    loadedRole = role;
    rows = [];
    registrationStatuses.clear();
    error = null;
    if (!navigation.canOpenManagement(widget.index) || path.isEmpty) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await ApiService.request('GET', path);
      if (!mounted || version != loadVersion) return;
      final d = ApiService.unwrap(r);
      rows = d is List ? d : (d is Map && widget.index == 2 ? [d] : []);

      if (widget.index == 13) {
        final summary = ApiService.unwrap(
          await ApiService.request('GET', '/api/points/my'),
        );
        if (!mounted || version != loadVersion) return;
        totalPoints =
            num.tryParse('${summary is Map ? summary['total_points'] : 0}') ??
            0;
      }
      if (role == 'student' && [1, 2].contains(widget.index)) {
        final registrationResponse = await ApiService.request(
          'GET',
          '/api/registrations/my',
        );
        if (!mounted || version != loadVersion) return;
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
      if (version == loadVersion) error = e.toString();
    } finally {
      if (mounted && version == loadVersion) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> call(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    if (!navigation.canOpenManagement(widget.index)) return;
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
    if (!navigation.canOpenManagement(widget.index)) {
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 12),
          _unavailable(),
        ],
      );
    }
    if (widget.index == 16) return const SystemSettingsScreen();
    final tool = switch (widget.index) {
      3 when navigation.isLecturer => ActivityTool.participants,
      4 => ActivityTool.checkIn,
      5 || 6 => ActivityTool.qr,
      _ => null,
    };
    if (tool != null) {
      return ActivityToolScreen(
        tool: tool,
        activityId: widget.activityId,
        onNavigate: widget.onNavigate,
      );
    }
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
        if (widget.index == 13) _points(),
        if (widget.index == 14) _users(),
        if (widget.index == 17) _studentDetails(),
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
          if (navigation.canManageActivities)
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

    if (!['published', 'ongoing'].contains(activity['status'])) {
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
    if (loading || error != null) return const SizedBox.shrink();
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _activityActions(m),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _activityActions(Map<String, dynamic> activity) {
    final id = int.tryParse('${activity['activity_id']}');
    return [
      if (widget.onNavigate != null && widget.index != 2)
        IconButton(
          tooltip: context.tr('รายละเอียดกิจกรรม'),
          icon: const Icon(Icons.info_outline),
          onPressed: id == null
              ? null
              : () => widget.onNavigate!(AppPage.activityDetails, id),
        ),
      if (navigation.isStudent) ...[
        _studentJoinButton(activity),
        if (widget.onNavigate != null &&
            registrationStatuses[id] == 'registered' &&
            ['published', 'ongoing'].contains(activity['status']))
          TextButton.icon(
            onPressed: () => widget.onNavigate!(AppPage.checkIn, id),
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(context.tr('เช็คอิน QR')),
          ),
      ],
      if (_canEditActivity(activity)) ...[
        IconButton(
          tooltip: context.tr('แก้ไข'),
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: busy ? null : () => _activityForm(existing: activity),
        ),
        if (widget.onNavigate != null && navigation.isLecturer)
          IconButton(
            tooltip: context.tr('ผู้เข้าร่วม'),
            icon: const Icon(Icons.groups),
            onPressed: () => widget.onNavigate!(AppPage.registrations, id),
          ),
        if (widget.onNavigate != null &&
            ['published', 'ongoing'].contains(activity['status']))
          IconButton(
            tooltip: context.tr('สร้าง QR Code'),
            icon: const Icon(Icons.qr_code),
            onPressed: () => widget.onNavigate!(AppPage.qrCodes, id),
          ),
        IconButton(
          tooltip: context.tr('ยกเลิกกิจกรรม'),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: busy || activity['status'] == 'cancelled'
              ? null
              : () => _confirmCancel(activity),
        ),
      ],
    ];
  }

  bool _canEditActivity(Map<String, dynamic> activity) =>
      navigation.isAdmin ||
      (navigation.isLecturer &&
          ApiService.currentUser?['user_id'] != null &&
          '${activity['organizer_id']}' ==
              '${ApiService.currentUser?['user_id']}');

  Future<void> _activityForm({Map<String, dynamic>? existing}) async {
    Map<String, dynamic> options;
    setState(() => busy = true);
    try {
      options = Map<String, dynamic>.from(
        ApiService.unwrap(
          await ApiService.request('GET', '/api/activities/options'),
        ),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(exception.toString()))),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
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
    Uint8List? selectedImage;
    String? coverImage = existing?['cover_image']?.toString();
    String? saveError;
    bool saving = false, imageNeedsUpload = false;
    String selectedStatus = '${existing?['status'] ?? 'draft'}';
    if (![
      'draft',
      'published',
      'ongoing',
      'completed',
      'cancelled',
    ].contains(selectedStatus)) {
      selectedStatus = 'draft';
    }

    const mainFields = [
      'title',
      'category_id',
      'location',
      'start_at',
      'end_at',
    ];

    Widget input(String name) {
      final controller = fields[name]!;
      Widget child;
      if (['category_id', 'zone_id'].contains(name)) {
        final choices =
            options[name == 'category_id' ? 'categories' : 'zones'] as List? ??
            [];
        child = DropdownButtonFormField<int>(
          initialValue: int.tryParse(controller.text),
          isExpanded: true,
          decoration: InputDecoration(labelText: context.fieldLabel(name)),
          items: [
            if (name == 'zone_id')
              DropdownMenuItem(
                value: 0,
                child: Text(context.tr('ไม่ระบุพื้นที่')),
              ),
            for (final item in choices)
              DropdownMenuItem(
                value: int.parse('${item[name]}'),
                child: Text(
                  '${item[name == 'category_id' ? 'category_name' : 'zone_name']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (int.tryParse(controller.text) != null &&
                !choices.any((item) => '${item[name]}' == controller.text))
              DropdownMenuItem(
                value: int.parse(controller.text),
                child: Text(controller.text),
              ),
          ],
          validator: (value) => name == 'category_id' && value == null
              ? context.tr('กรุณากรอกข้อมูล')
              : null,
          onChanged: (value) =>
              controller.text = value == null || value == 0 ? '' : '$value',
        );
      } else if (['start_at', 'end_at'].contains(name)) {
        child = ActivityDateTimeField(
          controller: controller,
          label: context.fieldLabel(name),
          after: name == 'end_at' ? fields['start_at'] : null,
        );
      } else {
        child = TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: context.fieldLabel(name)),
          validator: (value) =>
              mainFields.contains(name) &&
                  (value == null || value.trim().isEmpty)
              ? context.tr('กรุณากรอกข้อมูล')
              : null,
        );
      }
      return Padding(
        key: ValueKey('activity-field-$name'),
        padding: const EdgeInsets.only(bottom: 12),
        child: child,
      );
    }

    final dialog = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            context.tr(existing == null ? 'เพิ่มกิจกรรม' : 'แก้ไขกิจกรรม'),
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final name in mainFields) input(name),
                    if (selectedImage != null ||
                        (coverImage?.isNotEmpty ?? false)) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: selectedImage != null
                            ? Image.memory(
                                selectedImage!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : ActivityCoverImage(url: coverImage!, height: 160),
                      ),
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () => setDialogState(() {
                                selectedImage = null;
                                coverImage = null;
                                imageNeedsUpload = false;
                              }),
                        icon: const Icon(Icons.close),
                        label: Text(context.tr('ลบรูป')),
                      ),
                    ],
                    OutlinedButton.icon(
                      key: const ValueKey('pick-activity-image'),
                      onPressed: saving
                          ? null
                          : () async {
                              try {
                                final image = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1600,
                                  maxHeight: 1000,
                                  imageQuality: 82,
                                );
                                if (image == null) return;
                                final bytes = await image.readAsBytes();
                                if (bytes.length > 3 * 1024 * 1024) {
                                  throw const FormatException(
                                    'Choose an image smaller than 3 MB',
                                  );
                                }
                                if (ctx.mounted) {
                                  setDialogState(() {
                                    selectedImage = bytes;
                                    imageNeedsUpload = true;
                                    saveError = null;
                                  });
                                }
                              } catch (exception) {
                                if (ctx.mounted) {
                                  setDialogState(
                                    () => saveError = exception.toString(),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(context.tr('เพิ่มรูปกิจกรรม (ไม่บังคับ)')),
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      key: const ValueKey('activity-more-settings'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 12),
                      maintainState: true,
                      title: Text(context.tr('ตั้งค่าเพิ่มเติม (ไม่บังคับ)')),
                      subtitle: Text(context.statusLabel(selectedStatus)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            key: const ValueKey('activity-field-status'),
                            initialValue: selectedStatus,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: context.tr('สถานะกิจกรรม'),
                            ),
                            items: [
                              for (final entry in const {
                                'draft': 'ฉบับร่าง',
                                'published': 'เผยแพร่ / เปิดรับสมัคร',
                                'ongoing': 'กำลังดำเนินการ',
                                'completed': 'เสร็จสิ้น',
                                'cancelled': 'ยกเลิกกิจกรรม',
                              }.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    context.tr(entry.value),
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
                        ),
                        for (final name in fields.keys.where(
                          (name) => !mainFields.contains(name),
                        ))
                          input(name),
                      ],
                    ),
                    if (saveError != null)
                      Text(
                        context.tr(saveError!),
                        style: const TextStyle(color: Colors.red),
                      ),
                    if (saving) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: Text(context.tr('ยกเลิก')),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        saveError = null;
                      });
                      try {
                        if (imageNeedsUpload && selectedImage != null) {
                          final imageData = ApiService.unwrap(
                            await ApiService.request(
                              'POST',
                              '/api/activities/image',
                              body: {'image': base64Encode(selectedImage!)},
                            ),
                          );
                          coverImage = '${imageData['url']}';
                          imageNeedsUpload = false;
                        }
                        final body = <String, dynamic>{
                          'category_id': int.tryParse(
                            fields['category_id']!.text,
                          ),
                          'title': fields['title']!.text,
                          'location': fields['location']!.text,
                          'start_at': fields['start_at']!.text,
                          'end_at': fields['end_at']!.text,
                          'description': fields['description']!.text,
                          'points': int.tryParse(fields['points']!.text) ?? 0,
                          'zone_id': int.tryParse(fields['zone_id']!.text),
                          'max_participants': int.tryParse(
                            fields['max_participants']!.text,
                          ),
                          'status': selectedStatus,
                          'cover_image': coverImage,
                        };
                        await ApiService.request(
                          existing == null ? 'POST' : 'PUT',
                          existing == null
                              ? '/api/activities'
                              : '/api/activities/${existing['activity_id']}',
                          body: body,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (exception) {
                        if (ctx.mounted) {
                          setDialogState(
                            () => saveError = exception.toString(),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDialogState(() => saving = false);
                      }
                    },
              child: Text(context.tr('บันทึก')),
            ),
          ],
        ),
      ),
    );
    final ok = await Navigator.of(context, rootNavigator: true).push(dialog);
    await dialog.completed;
    if (ok == true && mounted) {
      await load();
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
      if (rows.length == 1 && '${rows.first['cover_image'] ?? ''}'.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ActivityCoverImage(
            url: '${rows.first['cover_image']}',
            height: 240,
          ),
        ),
      const SizedBox(height: 10),
      if (widget.activityId != null &&
          !loading &&
          error == null &&
          rows.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activityActions(Map<String, dynamic>.from(rows.first)),
        ),
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
    if (navigation.isStudent) {
      if (loading || error != null) return const SizedBox.shrink();
      if (rows.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
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
            rows: rows.whereType<Map>().map((raw) {
              final registration = Map<String, dynamic>.from(raw);
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      '${registration['title'] ?? registration['activity_title'] ?? registration['activity_id']}',
                    ),
                  ),
                  DataCell(
                    Text(
                      context.statusLabel(
                        registration['registration_status'] ??
                            registration['status'],
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onNavigate != null &&
                            registration['registration_status'] ==
                                'registered' &&
                            [
                              'published',
                              'ongoing',
                            ].contains(registration['activity_status']))
                          TextButton.icon(
                            onPressed: () => widget.onNavigate!(
                              AppPage.checkIn,
                              int.parse('${registration['activity_id']}'),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(context.tr('เช็คอิน QR')),
                          ),
                        TextButton(
                          onPressed:
                              !busy &&
                                  (registration['registration_status'] ??
                                          registration['status']) ==
                                      'registered'
                              ? () => _confirmCancelRegistration(
                                  int.parse('${registration['activity_id']}'),
                                )
                              : null,
                          child: Text(context.tr('ยกเลิก')),
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
    return const SizedBox.shrink();
  }

  Widget _unavailable() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 40, color: Colors.blueGrey),
          const SizedBox(height: 8),
          Text(context.tr('หน้านี้ไม่พร้อมใช้งานสำหรับบัญชีของคุณ')),
        ],
      ),
    ),
  );

  Widget _points() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!loading && error == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            context.tr('คะแนนรวม: {points}', args: {'points': '$totalPoints'}),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      Text(
        context.tr('ประวัติคะแนนของบัญชีที่เข้าสู่ระบบ'),
        style: const TextStyle(color: Colors.blueGrey),
      ),
      const SizedBox(height: 10),
      if (!loading && error == null)
        _dataTable(rows, ['activity_title', 'points', 'created_at']),
    ],
  );

  Future<void> _createLecturer() async {
    final name = TextEditingController(),
        email = TextEditingController(),
        password = TextEditingController();
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('สร้างบัญชีอาจารย์')),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(
                      'อาจารย์ต้องเปลี่ยนรหัสผ่านเมื่อเข้าสู่ระบบครั้งแรก',
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final entry in {
                    'ชื่อ': name,
                    'อีเมล': email,
                    'รหัสผ่านชั่วคราว': password,
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: entry.value,
                        obscureText: entry.value == password,
                        decoration: InputDecoration(
                          labelText: context.tr(entry.key),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('กรุณากรอกข้อมูล');
                          }
                          if (entry.value == email &&
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value.trim())) {
                            return context.tr('กรุณากรอกอีเมลที่ถูกต้อง');
                          }
                          if (entry.value == password && value.length < 8) {
                            return context.tr(
                              'รหัสผ่านใหม่ (อย่างน้อย 8 ตัวอักษร)',
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('ยกเลิก')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(context.tr('สร้าง')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await call(
        'POST',
        '/api/admin/lecturers',
        body: {
          'full_name': name.text.trim(),
          'email': email.text.trim(),
          'password': password.text,
        },
      );
    }
    // Dialog exit animations may still read the field controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    email.dispose();
    password.dispose();
  }

  Widget _users() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: busy ? null : _createLecturer,
            icon: const Icon(Icons.person_add),
            label: Text(context.tr('สร้างบัญชีอาจารย์')),
          ),
        ),
        const SizedBox(height: 12),
        Text(context.tr('จัดการบัญชีผู้ใช้จาก /api/admin/users')),
        const SizedBox(height: 10),
        if (rows.isNotEmpty)
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(context.tr('รหัส'))),
                  DataColumn(label: Text(context.tr('รหัสนักศึกษา'))),
                  DataColumn(label: Text(context.tr('ชื่อ'))),
                  DataColumn(label: Text(context.tr('อีเมล'))),
                  DataColumn(label: Text(context.fieldLabel('role'))),
                  DataColumn(label: Text(context.tr('คะแนน'))),
                  DataColumn(label: Text(context.tr('สถานะ'))),
                  DataColumn(label: Text(context.tr('จัดการ'))),
                ],
                rows: rows.whereType<Map>().map((u) {
                  final m = Map<String, dynamic>.from(u);
                  final active = m['is_active'] == 1 || m['is_active'] == true;
                  return DataRow(
                    cells: [
                      DataCell(Text('${m['user_id']}')),
                      DataCell(Text('${m['student_code'] ?? '-'}')),
                      DataCell(Text('${m['full_name']}')),
                      DataCell(Text('${m['email']}')),
                      DataCell(Text(context.statusLabel(m['role']))),
                      DataCell(
                        Text(
                          m['role'] == 'student'
                              ? '${m['total_points'] ?? 0}'
                              : '-',
                        ),
                      ),
                      DataCell(
                        Text(
                          active
                              ? context.tr('ใช้งาน')
                              : context.tr('ปิดใช้งาน'),
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed:
                              busy ||
                                  '${m['user_id']}' ==
                                      '${ApiService.currentUser?['user_id']}'
                              ? null
                              : () => call(
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

  Widget _studentDetails() {
    final students = rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (students.isEmpty && !loading && error == null) {
      return Text(context.tr('ไม่มีข้อมูลผู้ใช้'));
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            for (final label in [
              'รหัส',
              'รหัสนักศึกษา',
              'ชื่อ',
              'อีเมล',
              'คะแนน',
              'สถานะ',
            ])
              DataColumn(label: Text(context.tr(label))),
          ],
          rows: [
            for (final student in students)
              DataRow(
                cells: [
                  DataCell(Text('${student['user_id'] ?? '-'}')),
                  DataCell(Text('${student['student_code'] ?? '-'}')),
                  DataCell(Text('${student['full_name'] ?? '-'}')),
                  DataCell(Text('${student['email'] ?? '-'}')),
                  DataCell(Text('${student['total_points'] ?? 0}')),
                  DataCell(
                    Text(
                      student['is_active'] == 1 || student['is_active'] == true
                          ? context.tr('ใช้งาน')
                          : context.tr('ปิดใช้งาน'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _label(String s) => context.fieldLabel(s);
}
