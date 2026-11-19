import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  List<Map<String, dynamic>> categories = [], zones = [], addresses = [];
  bool loading = true, busy = false;
  int selected = 0, version = 0;
  String? error;

  bool get isAdmin =>
      AppNavigation(ApiService.currentUser?['role']?.toString()).isAdmin;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    version++;
    super.dispose();
  }

  Future<void> load() async {
    if (!isAdmin) {
      setState(() => loading = false);
      return;
    }
    final current = ++version;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = ApiService.unwrap(
        await ApiService.request('GET', '/api/admin/settings'),
      );
      if (!mounted || current != version) return;
      List<Map<String, dynamic>> rows(String field) => (data[field] as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      categories = rows('categories');
      zones = rows('zones');
      addresses = rows('allowed_ips');
    } catch (exception) {
      if (current == version) error = exception.toString();
    } finally {
      if (mounted && current == version) setState(() => loading = false);
    }
  }

  Future<void> save(
    String method,
    String endpoint, [
    Map<String, dynamic>? body,
  ]) async {
    if (!isAdmin || busy) return;
    setState(() => busy = true);
    try {
      final result = await ApiService.request(
        method,
        '/api/admin/settings/$endpoint',
        body: body,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('${result['message']}'))),
      );
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

  bool validRange(String value) {
    final parts = value.trim().split('/');
    final bytes = parts.first.split('.');
    final prefix = parts.length == 1 ? 32 : int.tryParse(parts[1]);
    return parts.length <= 2 &&
        bytes.length == 4 &&
        bytes.every(
          (part) =>
              RegExp(r'^\d{1,3}$').hasMatch(part) &&
              int.parse(part) <= 255 &&
              (part.length == 1 || !part.startsWith('0')),
        ) &&
        prefix != null &&
        prefix >= 1 &&
        prefix <= 32;
  }

  Future<void> edit(
    String kind, {
    Map<String, dynamic>? item,
    int? zoneId,
  }) async {
    final ip = kind == 'ips';
    final nameField = ip
        ? 'ip_range'
        : kind == 'categories'
        ? 'category_name'
        : 'zone_name';
    final idField = ip
        ? 'ip_id'
        : kind == 'categories'
        ? 'category_id'
        : 'zone_id';
    final title = ip
        ? 'IP ที่อนุญาต'
        : kind == 'categories'
        ? 'หมวดหมู่กิจกรรม'
        : 'พื้นที่เครือข่าย';
    final name = TextEditingController(text: '${item?[nameField] ?? ''}');
    final description = TextEditingController(
      text: '${item?['description'] ?? ''}',
    );
    var active =
        item == null || item['is_active'] == 1 || item['is_active'] == true;
    final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, updateDialog) => AlertDialog(
          title: Text(context.tr(title)),
          content: SizedBox(
            width: 460,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const ValueKey('settings-name'),
                      controller: name,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          ip ? 'ที่อยู่ IPv4 หรือ CIDR' : 'ชื่อ',
                        ),
                      ),
                      maxLength: ip ? 50 : 100,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('กรุณากรอกข้อมูล');
                        }
                        if (ip && !validRange(value)) {
                          return context.tr(
                            'กรุณากรอก IPv4 หรือ CIDR ที่ถูกต้อง (1–32)',
                          );
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: description,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.tr('คำอธิบาย'),
                      ),
                    ),
                    if (!ip)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.tr('ใช้งาน')),
                        value: active,
                        onChanged: (value) =>
                            updateDialog(() => active = value),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('ยกเลิก')),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(dialogContext, <String, dynamic>{
                  nameField: name.text.trim(),
                  'description': description.text.trim(),
                  if (ip)
                    'zone_id': zoneId ?? item?['zone_id']
                  else
                    'is_active': active,
                });
              },
              child: Text(context.tr('บันทึก')),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await save(
        item == null ? 'POST' : 'PATCH',
        item == null ? kind : '$kind/${item[idField]}',
        result,
      );
    }
    // The closing dialog animation may still be displaying its input fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    description.dispose();
  }

  Future<void> removeIp(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('ลบ IP ที่อนุญาตหรือไม่?')),
        content: Text('${item['ip_range']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('ยกเลิก')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('ลบ')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await save('DELETE', 'ips/${item['ip_id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Center(
        child: Text(context.tr('หน้านี้ไม่พร้อมใช้งานสำหรับบัญชีของคุณ')),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              onTap: (value) => setState(() => selected = value),
              tabs: [
                Tab(text: context.tr('หมวดหมู่กิจกรรม')),
                Tab(text: context.tr('เครือข่ายมหาวิทยาลัย')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('ตั้งค่าระบบ'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('รีเฟรช'),
                      onPressed: loading || busy ? null : load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (loading || busy) const LinearProgressIndicator(),
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
                if (!loading && error == null) ...[
                  const SizedBox(height: 12),
                  if (selected == 0) ..._categories() else ..._network(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _categories() => [
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        key: const ValueKey('add-category'),
        onPressed: busy ? null : () => edit('categories'),
        icon: const Icon(Icons.add),
        label: Text(context.tr('เพิ่มหมวดหมู่')),
      ),
    ),
    const SizedBox(height: 12),
    if (categories.isEmpty)
      Text(context.tr('เพิ่มหมวดหมู่เพื่อให้อาจารย์สร้างกิจกรรมได้')),
    for (final category in categories)
      Card(
        child: ListTile(
          title: Text('${category['category_name']}'),
          subtitle: category['description'] == null
              ? null
              : Text('${category['description']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: ValueKey('edit-category-${category['category_id']}'),
                tooltip: context.tr('แก้ไข'),
                onPressed: busy
                    ? null
                    : () => edit('categories', item: category),
                icon: const Icon(Icons.edit_outlined),
              ),
              Switch(
                key: ValueKey('category-active-${category['category_id']}'),
                value:
                    category['is_active'] == 1 || category['is_active'] == true,
                onChanged: busy
                    ? null
                    : (value) => save(
                        'PATCH',
                        'categories/${category['category_id']}',
                        {'is_active': value},
                      ),
              ),
            ],
          ),
        ),
      ),
  ];

  List<Widget> _network() => [
    Text(
      context.tr(
        'เช็คอินได้จากทุกเครือข่าย พื้นที่เครือข่ายเป็นข้อมูลเสริมของกิจกรรม ไม่จำกัดการเช็คอิน',
      ),
    ),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        key: const ValueKey('add-zone'),
        onPressed: busy ? null : () => edit('zones'),
        icon: const Icon(Icons.add),
        label: Text(context.tr('เพิ่มพื้นที่เครือข่าย')),
      ),
    ),
    const SizedBox(height: 12),
    if (zones.isEmpty)
      Text(context.tr('เพิ่มพื้นที่เครือข่ายก่อนกำหนด IP ที่อนุญาต')),
    for (final zone in zones)
      Card(
        child: ExpansionTile(
          key: PageStorageKey('settings-zone-${zone['zone_id']}'),
          initiallyExpanded: zones.length <= 2,
          title: Text('${zone['zone_name']}'),
          subtitle: zone['description'] == null
              ? null
              : Text('${zone['description']}'),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(context.tr('ใช้งาน')),
                Switch(
                  key: ValueKey('zone-active-${zone['zone_id']}'),
                  value: zone['is_active'] == 1 || zone['is_active'] == true,
                  onChanged: busy
                      ? null
                      : (value) => save('PATCH', 'zones/${zone['zone_id']}', {
                          'is_active': value,
                        }),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => edit('zones', item: zone),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.tr('แก้ไข')),
                ),
                TextButton.icon(
                  key: ValueKey('add-ip-${zone['zone_id']}'),
                  onPressed: busy
                      ? null
                      : () => edit(
                          'ips',
                          zoneId: int.parse('${zone['zone_id']}'),
                        ),
                  icon: const Icon(Icons.add_link),
                  label: Text(context.tr('เพิ่ม IP ที่อนุญาต')),
                ),
              ],
            ),
            for (final ip in addresses.where(
              (row) => '${row['zone_id']}' == '${zone['zone_id']}',
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${ip['ip_range']}'),
                subtitle: ip['description'] == null
                    ? null
                    : Text('${ip['description']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('edit-ip-${ip['ip_id']}'),
                      tooltip: context.tr('แก้ไข'),
                      onPressed: busy ? null : () => edit('ips', item: ip),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      key: ValueKey('remove-ip-${ip['ip_id']}'),
                      tooltip: context.tr('ลบ'),
                      onPressed: busy ? null : () => removeIp(ip),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            if (!addresses.any(
              (row) => '${row['zone_id']}' == '${zone['zone_id']}',
            ))
              Text(context.tr('ยังไม่มี IP ที่อนุญาตในพื้นที่นี้')),
          ],
        ),
      ),
  ];
}
