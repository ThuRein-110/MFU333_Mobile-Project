import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'management_screen.dart';
import 'password_screen.dart';
import 'login_screen.dart';

class AppShell extends StatefulWidget {
  final bool forcePassword;

  const AppShell({super.key, this.forcePassword = false});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;

  final titles = const [
    'ภาพรวมระบบ',
    'กิจกรรม',
    'รายละเอียดกิจกรรม',
    'จัดการผู้ลงทะเบียน',
    'เช็คอิน QR',
    'จัดการ QR Code',
    'เพิ่ม / แก้ไข QR',
    'หมวดหมู่กิจกรรม',
    'เพิ่ม / แก้ไขหมวดหมู่',
    'พื้นที่เครือข่าย',
    'เพิ่ม / แก้ไขพื้นที่',
    'IP ที่อนุญาต',
    'เพิ่ม / แก้ไข IP',
    'ประวัติคะแนนสะสม',
    'บัญชีผู้ใช้',
    'เปลี่ยนรหัสผ่าน',
  ];

  final icons = const [
    Icons.dashboard_outlined,
    Icons.event_note,
    Icons.event,
    Icons.groups,
    Icons.qr_code_scanner,
    Icons.qr_code,
    Icons.add_box,
    Icons.category,
    Icons.create,
    Icons.wifi,
    Icons.add_location_alt,
    Icons.router,
    Icons.add_link,
    Icons.stars,
    Icons.people,
    Icons.lock_reset,
  ];

  @override
  void initState() {
    super.initState();

    if (widget.forcePassword) {
      selected = 15;
    }
  }

  String get _role =>
      '${ApiService.currentUser?['role'] ?? ''}'.trim().toLowerCase();

  List<int> get _visibleMenuIndices {
    if (_role == 'student') return [0, 1, 4, 13, 15];
    if (_role == 'lecturer') {
      // Lecturer can manage/generate QR (index 5), but cannot scan/check-in (index 4).
      return List<int>.generate(titles.length, (i) => i)
          .where((i) => i != 4)
          .toList();
    }
    return List<int>.generate(titles.length, (i) => i);
  }

  List<int> get _mobileMenuIndices {
    if (_role == 'student') return [0, 1, 4, 13, 15];
    if (_role == 'lecturer') return [0, 1, 2, 3, 5];
    return [0, 1, 2, 3, 4];
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    final user = ApiService.currentUser ?? {};
    final mobileIndices = _mobileMenuIndices;

    // Block direct/stale navigation to the student scanner for lecturers.
    if (_role == 'lecturer' && selected == 4) {
      selected = 1;
    }

    Widget page;

    if (selected == 0) {
      page = const DashboardScreen();
    } else if (selected == 15) {
      page = const PasswordScreen();
    } else {
      page = ManagementScreen(index: selected, title: titles[selected]);
    }

    return Scaffold(
      body: Row(
        children: [
          if (wide) _sidebar(),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 62,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  color: Colors.white,
                  child: Row(
                    children: [
                      if (!wide)
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('เมนูอยู่ในปุ่มรายการด้านล่าง'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu),
                        ),
                      const Text(
                        'MFU333',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF102A4C),
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.notifications_none,
                        color: Color(0xFF52657A),
                      ),
                      const SizedBox(width: 18),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE5F0FF),
                        child: Text(
                          (user['full_name'] ?? 'U')
                              .toString()
                              .characters
                              .first
                              .toUpperCase(),
                          style: const TextStyle(color: Color(0xFF1265E8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(user['full_name']?.toString() ?? 'ผู้ใช้งาน'),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'logout') {
                            await ApiService.logout();

                            if (!context.mounted) return;

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (_) => false,
                            );
                          } else {
                            setState(() {
                              selected = 15;
                            });
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'password',
                            child: Text('เปลี่ยนรหัสผ่าน'),
                          ),
                          PopupMenuItem(
                            value: 'logout',
                            child: Text('ออกจากระบบ'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: page),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: mobileIndices.indexOf(selected) < 0
                  ? 0
                  : mobileIndices.indexOf(selected),
              onDestinationSelected: (v) {
                setState(() {
                  selected = mobileIndices[v];
                });
              },
              destinations: [
                for (final i in mobileIndices)
                  NavigationDestination(
                    icon: Icon(icons[i]),
                    label: titles[i] == 'ภาพรวมระบบ' ? 'ภาพรวม' : titles[i],
                  ),
              ],
            ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 238,
      color: const Color(0xFF102A4C),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'MFU333',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _visibleMenuIndices.length,
              itemBuilder: (_, position) {
                final i = _visibleMenuIndices[position];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 2,
                  ),
                  child: ListTile(
                    dense: true,
                    selected: selected == i,
                    selectedTileColor: const Color(0xFF2366A7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(icons[i], color: Colors.white, size: 19),
                    title: Text(
                      titles[i],
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    onTap: () {
                      setState(() {
                        selected = i;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Campus Activity System',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
