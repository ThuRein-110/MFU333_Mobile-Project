import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_strings.dart';
import '../navigation/app_navigation.dart';
import '../services/activity_qr.dart';
import '../services/api_service.dart';
import '../widgets/activity_date_time_field.dart';

enum ActivityTool { participants, qr, checkIn }

class ActivityToolScreen extends StatefulWidget {
  const ActivityToolScreen({
    super.key,
    required this.tool,
    this.activityId,
    this.onNavigate,
  });

  final ActivityTool tool;
  final int? activityId;
  final void Function(AppPage page, int? activityId)? onNavigate;

  @override
  State<ActivityToolScreen> createState() => _ActivityToolScreenState();
}

class _ActivityToolScreenState extends State<ActivityToolScreen> {
  List<Map<String, dynamic>> activities = [], participants = [], qrCodes = [];
  int? selectedId;
  bool loading = true, busy = false, camera = false;
  int version = 0;
  String? error, lastScan;
  num? awardedPoints;
  ActivityQr? incomingQr;
  final tokenInput = TextEditingController();
  final starts = TextEditingController();
  final expires = TextEditingController();

  AppNavigation get access =>
      AppNavigation(ApiService.currentUser?['role']?.toString());
  bool get allowed => switch (widget.tool) {
    ActivityTool.participants => access.isLecturer,
    ActivityTool.qr => access.canManageActivities,
    ActivityTool.checkIn => access.isStudent,
  };

  @override
  void initState() {
    super.initState();
    selectedId = widget.activityId;
    if (widget.tool == ActivityTool.checkIn) {
      incomingQr = ActivityQr.pendingCheckIn;
      if (incomingQr != null &&
          (selectedId == null || selectedId == incomingQr!.activityId)) {
        selectedId = incomingQr!.activityId;
        tokenInput.text = incomingQr!.token;
      } else {
        incomingQr = null;
      }
    }
    final now = DateTime.now().toUtc();
    starts.text = now.toIso8601String();
    expires.text = now.add(const Duration(hours: 1)).toIso8601String();
    load();
  }

  @override
  void didUpdateWidget(covariant ActivityToolScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId != widget.activityId ||
        oldWidget.tool != widget.tool) {
      selectedId = widget.activityId;
      awardedPoints = null;
      load();
    }
  }

  @override
  void dispose() {
    version++;
    tokenInput.dispose();
    starts.dispose();
    expires.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final requestVersion = ++version;
    if (!allowed) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = ApiService.unwrap(
        await ApiService.request(
          'GET',
          widget.tool == ActivityTool.checkIn
              ? '/api/registrations/my'
              : '/api/activities',
        ),
      );
      if (!mounted || version != requestVersion) return;
      activities = (response is List ? response : <dynamic>[])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) {
            if (widget.tool == ActivityTool.checkIn) {
              return (row['registration_status'] ?? row['status']) ==
                      'registered' &&
                  ['published', 'ongoing'].contains(row['activity_status']);
            }
            final owned =
                access.isAdmin ||
                (ApiService.currentUser?['user_id'] != null &&
                    '${row['organizer_id']}' ==
                        '${ApiService.currentUser?['user_id']}');
            return owned;
          })
          .toList();
      if (incomingQr != null &&
          activities.any(
            (row) => '${row['activity_id']}' == '${incomingQr!.activityId}',
          )) {
        selectedId = incomingQr!.activityId;
      }
      if (!activities.any(
        (row) => int.tryParse('${row['activity_id']}') == selectedId,
      )) {
        selectedId = activities.isEmpty
            ? null
            : int.tryParse('${activities.first['activity_id']}');
      }
      participants = [];
      qrCodes = [];
      if (widget.tool == ActivityTool.qr && selectedId != null) {
        final result = ApiService.unwrap(
          await ApiService.request('GET', '/api/qr/$selectedId'),
        );
        if (!mounted || version != requestVersion) return;
        qrCodes = (result is List ? result : <dynamic>[])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      if (widget.tool == ActivityTool.participants && selectedId != null) {
        final result = ApiService.unwrap(
          await ApiService.request(
            'GET',
            '/api/lecturer/activities/$selectedId/participants',
          ),
        );
        if (!mounted || version != requestVersion) return;
        participants = (result is List ? result : <dynamic>[])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
    } catch (exception) {
      if (version == requestVersion) error = exception.toString();
    } finally {
      if (mounted && version == requestVersion) setState(() => loading = false);
    }
  }

  bool get needsRegistration =>
      incomingQr != null &&
      !activities.any(
        (row) => '${row['activity_id']}' == '${incomingQr!.activityId}',
      );

  @override
  Widget build(BuildContext context) {
    if (!allowed) {
      return Center(
        child: Text(context.tr('หน้านี้ไม่พร้อมใช้งานสำหรับบัญชีของคุณ')),
      );
    }
    final title = switch (widget.tool) {
      ActivityTool.participants => 'จัดการผู้ลงทะเบียน',
      ActivityTool.qr => 'จัดการ QR Code',
      ActivityTool.checkIn => 'เช็คอิน QR',
    };
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr(title),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: context.tr('รีเฟรช'),
              onPressed: busy || loading ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    context.tr(error!),
                    style: const TextStyle(color: Colors.red),
                  ),
                  TextButton(
                    onPressed: load,
                    child: Text(context.tr('ลองอีกครั้ง')),
                  ),
                ],
              ),
            ),
          ),
        if (awardedPoints != null) _success(),
        if (!loading && error == null && awardedPoints == null) ...[
          if (needsRegistration)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      context.tr(
                        'ลงทะเบียนกิจกรรมจาก QR ก่อนเช็คอิน หรือดูสถานะการเข้าร่วมของคุณ',
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onNavigate == null
                          ? null
                          : () => widget.onNavigate!(
                              AppPage.activityDetails,
                              incomingQr!.activityId,
                            ),
                      child: Text(context.tr('ดูกิจกรรมนี้')),
                    ),
                  ],
                ),
              ),
            )
          else if (activities.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      context.tr(
                        widget.tool == ActivityTool.checkIn
                            ? 'ลงทะเบียนกิจกรรมก่อนเช็คอิน'
                            : 'ยังไม่มีกิจกรรมที่ใช้งานได้',
                      ),
                    ),
                    if (widget.onNavigate != null)
                      TextButton(
                        onPressed: () =>
                            widget.onNavigate!(AppPage.activities, null),
                        child: Text(context.tr('ดูกิจกรรม')),
                      ),
                  ],
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<int>(
              key: ValueKey('activity-picker-$selectedId'),
              initialValue: selectedId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('เลือกกิจกรรม'),
              ),
              items: [
                for (final row in activities)
                  DropdownMenuItem(
                    value: int.parse('${row['activity_id']}'),
                    child: Text(
                      '${row['title']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      if (widget.onNavigate != null) {
                        widget.onNavigate!(switch (widget.tool) {
                          ActivityTool.participants => AppPage.registrations,
                          ActivityTool.qr => AppPage.qrCodes,
                          ActivityTool.checkIn => AppPage.checkIn,
                        }, value);
                        return;
                      }
                      selectedId = value;
                      incomingQr = null;
                      ActivityQr.pendingCheckIn = null;
                      tokenInput.clear();
                      lastScan = null;
                      load();
                    },
            ),
            const SizedBox(height: 16),
            if (widget.tool == ActivityTool.participants) _participants(),
            if (widget.tool == ActivityTool.qr) _qr(),
            if (widget.tool == ActivityTool.checkIn) _checkIn(),
          ],
          if (activities.isEmpty &&
              !needsRegistration &&
              widget.tool == ActivityTool.checkIn)
            _checkIn(),
        ],
      ],
    );
  }

  Widget _participants() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr(
          'ผู้ลงทะเบียน {registered} คน เข้าร่วมแล้ว {attended} คน',
          args: {
            'registered':
                '${participants.where((row) => ['registered', 'attended'].contains(row['registration_status'])).length}',
            'attended':
                '${participants.where((row) => row['registration_status'] == 'attended').length}',
          },
        ),
      ),
      const SizedBox(height: 12),
      if (participants.isEmpty)
        Text(context.tr('ยังไม่มีรายการลงทะเบียน'))
      else
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                for (final label in [
                  'ชื่อ',
                  'รหัสนักศึกษา',
                  'อีเมล',
                  'คะแนน',
                  'สถานะ',
                  'เวลาเช็คอิน',
                ])
                  DataColumn(label: Text(context.tr(label))),
              ],
              rows: [
                for (final row in participants)
                  DataRow(
                    cells: [
                      DataCell(Text('${row['full_name'] ?? '-'}')),
                      DataCell(Text('${row['student_code'] ?? '-'}')),
                      DataCell(Text('${row['email'] ?? '-'}')),
                      DataCell(Text('${row['total_points'] ?? 0}')),
                      DataCell(
                        Text(context.statusLabel(row['registration_status'])),
                      ),
                      DataCell(Text(_date(row['checked_in_at']))),
                    ],
                  ),
              ],
            ),
          ),
        ),
    ],
  );

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null ? '-' : formatActivityDateTime(context, parsed);
  }

  Widget _qr() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF1265E8)),
              const SizedBox(height: 12),
              Text(context.tr('สร้าง QR Code สำหรับให้นักศึกษาเช็คอินกิจกรรม')),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    busy ||
                        !['published', 'ongoing'].contains(
                          activities.firstWhere(
                            (row) => '${row['activity_id']}' == '$selectedId',
                          )['status'],
                        )
                    ? null
                    : _createQr,
                icon: const Icon(Icons.qr_code),
                label: Text(context.tr('สร้าง QR Code')),
              ),
              const SizedBox(height: 8),
              Text(context.tr('นักศึกษาจะได้รับแจ้งเตือนกิจกรรมเมื่อสร้าง QR')),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        context.tr('QR ที่บันทึกไว้'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (qrCodes.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(context.tr('ยังไม่มี QR สำหรับกิจกรรมนี้')),
        ),
      for (final code in qrCodes)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR #${code['qr_id']} · ${_qrStatus(code)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.tr('เริ่มใช้งาน')}: ${_date(code['starts_at'])}',
                ),
                Text('${context.tr('หมดอายุ')}: ${_date(code['expires_at'])}'),
                if (code['token'] == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      context.tr(
                        'QR เก่าบันทึกเฉพาะข้อมูลยืนยัน จึงเปิดภาพซ้ำไม่ได้ กรุณาสร้าง QR ใหม่หากต้องการภาพ',
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    key: ValueKey('show-qr-${code['qr_id']}'),
                    onPressed: () => _showQr(code),
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(context.tr('แสดง QR')),
                  ),
              ],
            ),
          ),
        ),
    ],
  );

  String _qrStatus(Map<String, dynamic> code) {
    final now = DateTime.now();
    if (code['is_active'] == 0 || code['is_active'] == false) {
      return context.tr('ปิดใช้งาน');
    }
    if (DateTime.tryParse('${code['expires_at']}')?.isBefore(now) ?? false) {
      return context.tr('หมดอายุแล้ว');
    }
    if (DateTime.tryParse('${code['starts_at']}')?.isAfter(now) ?? false) {
      return context.tr('กำหนดเวลาแล้ว');
    }
    return context.tr('ใช้งานได้');
  }

  Future<void> _createQr() async {
    final chosenId = selectedId;
    if (chosenId == null) return;
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('สร้าง QR Code')),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in {
                  'เริ่มใช้งาน': starts,
                  'หมดอายุ': expires,
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ActivityDateTimeField(
                      controller: entry.value,
                      label: context.tr(entry.key),
                      after: entry.value == expires ? starts : null,
                    ),
                  ),
              ],
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
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final data = ApiService.unwrap(
        await ApiService.request(
          'POST',
          '/api/qr/$chosenId',
          body: {'starts_at': starts.text, 'expires_at': expires.text},
        ),
      );
      if (!mounted) return;
      final code = Map<String, dynamic>.from(data as Map);
      setState(() => qrCodes.insert(0, code));
      await _showQr(code, created: true);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showQr(
    Map<String, dynamic> code, {
    bool created = false,
  }) async {
    final qr = ActivityQr(
      activityId: int.parse('${code['activity_id']}'),
      token: '${code['token']}',
    ).toLink();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(created ? 'สร้าง QR สำเร็จ' : 'แสดง QR')),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${activities.firstWhere((row) => '${row['activity_id']}' == '${code['activity_id']}')['title']}',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Semantics(
                    container: true,
                    image: true,
                    label: context.tr('QR สำหรับเช็คอินกิจกรรม'),
                    child: ExcludeSemantics(
                      child: QrImageView(
                        key: const ValueKey('attendance-qr-image'),
                        data: qr,
                        size: math.min(320, constraints.maxWidth),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(20),
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        semanticsLabel: context.tr('QR สำหรับเช็คอินกิจกรรม'),
                      ),
                    ),
                  ),
                ),
                Text(
                  context.tr(
                    'ใช้ได้ถึง {time}',
                    args: {'time': _date(code['expires_at'])},
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'สแกนด้วยกล้องโทรศัพท์เพื่อเปิดหน้าเช็คอิน หรือใช้กล้อง QR ในบัญชีนักศึกษา',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: qr));
            },
            child: Text(context.tr('คัดลอกลิงก์เช็คอิน')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('ปิด')),
          ),
        ],
      ),
    );
  }

  bool _acceptQr(String value) {
    try {
      final qr = ActivityQr.parse(value);
      final id = qr.activityId ?? selectedId;
      if (id == null ||
          !activities.any((row) => int.parse('${row['activity_id']}') == id)) {
        if (qr.activityId != null) {
          setState(() {
            incomingQr = qr;
            ActivityQr.pendingCheckIn = qr;
            camera = false;
            tokenInput.clear();
          });
          return false;
        }
        throw const FormatException(
          'Register for this activity before checking in',
        );
      }
      setState(() {
        incomingQr = qr.activityId == null
            ? ActivityQr(activityId: id, token: qr.token)
            : qr;
        ActivityQr.pendingCheckIn = incomingQr;
        selectedId = id;
        tokenInput.text = qr.token;
        camera = false;
      });
      return true;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('กรุณาลงทะเบียนกิจกรรมที่ตรงกับ QR ก่อนเช็คอิน'),
          ),
        ),
      );
      return false;
    }
  }

  Widget _checkIn() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (camera)
            SizedBox(
              height: 260,
              child: MobileScanner(
                errorBuilder: (context, error, child) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.tr(
                        'เปิดกล้องไม่ได้ กรุณาอนุญาตกล้องในเบราว์เซอร์ หรืออัปโหลดรูป QR แทน',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (value != null && value != lastScan) {
                    lastScan = value;
                    _acceptQr(value);
                  }
                },
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: busy ? null : () => setState(() => camera = true),
              icon: const Icon(Icons.camera_alt),
              label: Text(context.tr('เปิดกล้องสแกน QR')),
            ),
          if (camera)
            TextButton(
              onPressed: () => setState(() => camera = false),
              child: Text(context.tr('ปิดกล้อง')),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _readQrPhoto,
            icon: const Icon(Icons.image_outlined),
            label: Text(context.tr('อัปโหลดรูป QR')),
          ),
          if (incomingQr != null && tokenInput.text == incomingQr!.token) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('อ่าน QR แล้ว กรุณายืนยันเช็คอิน'),
              style: const TextStyle(color: Colors.green),
            ),
          ],
          const SizedBox(height: 12),
          if (incomingQr == null)
            TextField(
              controller: tokenInput,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.tr('วางลิงก์เช็คอินหรือโค้ด QR'),
              ),
            ),
          if (incomingQr != null)
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      incomingQr = null;
                      ActivityQr.pendingCheckIn = null;
                      tokenInput.clear();
                    }),
              child: Text(context.tr('ใช้ QR อื่น')),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy || tokenInput.text.trim().isEmpty
                ? null
                : _submitCheckIn,
            icon: const Icon(Icons.verified),
            label: Text(context.tr('ยืนยัน Check-in')),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'เช็คอินได้จากทุกเครือข่าย กรุณาลงทะเบียนกิจกรรมและใช้ QR ที่ยังไม่หมดอายุ',
            ),
            style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Future<void> _readQrPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;
      setState(() => busy = true);
      final bytes = await image.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        throw const FormatException('Choose an image smaller than 3 MB');
      }
      final data = ApiService.unwrap(
        await ApiService.request(
          'POST',
          '/api/checkins/read-qr',
          body: {'image': base64Encode(bytes)},
        ),
      );
      if (mounted) _acceptQr('${data['payload']}');
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(exception.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submitCheckIn() async {
    if (!_acceptQr(tokenInput.text)) return;
    setState(() => busy = true);
    try {
      final result = ApiService.unwrap(
        await ApiService.request(
          'POST',
          '/api/checkins',
          body: {'activity_id': selectedId, 'token': tokenInput.text.trim()},
        ),
      );
      if (!mounted) return;
      ActivityQr.pendingCheckIn = null;
      incomingQr = null;
      setState(() => awardedPoints = num.tryParse('${result['points']}') ?? 0);
      await load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(exception.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _success() => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'เช็คอินสำเร็จ ได้รับ {points} คะแนน',
              args: {'points': '$awardedPoints'},
            ),
          ),
          if (widget.onNavigate != null)
            FilledButton(
              onPressed: () => widget.onNavigate!(AppPage.points, null),
              child: Text(context.tr('ดูคะแนนสะสม')),
            ),
          TextButton(
            onPressed: () {
              setState(() {
                awardedPoints = null;
                tokenInput.clear();
              });
              load();
            },
            child: Text(context.tr('เช็คอินกิจกรรมอื่น')),
          ),
        ],
      ),
    ),
  );
}
