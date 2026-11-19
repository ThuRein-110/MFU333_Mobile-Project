import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../services/activity_qr.dart';
import '../widgets/language_switcher.dart';
import '../widgets/student_activity_alerts.dart';
import 'activities_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'management_screen.dart';
import 'password_screen.dart';

class AppShell extends StatefulWidget {
  final bool forcePassword;

  const AppShell({super.key, this.forcePassword = false});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  AppPage selected = AppPage.overview;
  AppPage activityPage = AppPage.activities;
  int? activityContextId;
  int? checkInActivityId;

  bool get mustChangePassword =>
      widget.forcePassword ||
      ApiService.currentUser?['must_change_password'] == true ||
      ApiService.currentUser?['must_change_password'] == 1;

  AppNavigation get navigation =>
      AppNavigation(ApiService.currentUser?['role']?.toString());

  @override
  void initState() {
    super.initState();
    ApiService.sessionInvalidated.addListener(_sessionInvalidated);
    if (mustChangePassword) selected = AppPage.password;
    if (!mustChangePassword &&
        navigation.isStudent &&
        ActivityQr.pendingCheckIn != null) {
      selected = AppPage.checkIn;
      checkInActivityId = ActivityQr.pendingCheckIn!.activityId;
    }
  }

  @override
  void dispose() {
    ApiService.sessionInvalidated.removeListener(_sessionInvalidated);
    super.dispose();
  }

  void _sessionInvalidated() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _selectPage(AppPage page) {
    if (page == AppPage.activities) {
      activityPage = AppPage.activities;
      activityContextId = null;
    }
    setState(() => selected = page);
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _openPage(AppPage page, int? id) {
    if (mustChangePassword) return;
    final access = navigation;
    if (access.activityPages.contains(page)) {
      setState(() {
        selected = AppPage.activities;
        activityPage = page;
        activityContextId = id;
      });
    } else if (access.primaryPages.contains(page)) {
      setState(() {
        selected = page;
        if (page == AppPage.checkIn) checkInActivityId = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    final user = ApiService.currentUser ?? {};
    final access = navigation;
    final pages = mustChangePassword ? [AppPage.password] : access.primaryPages;

    if (mustChangePassword) selected = AppPage.password;

    if (selected != AppPage.password && !pages.contains(selected)) {
      selected = AppPage.overview;
    }

    final Widget page = switch (selected) {
      AppPage.overview => DashboardScreen(
        key: ValueKey(access.role),
        onOpenActivity: (id) => _openPage(AppPage.activityDetails, id),
      ),
      AppPage.password => const PasswordScreen(),
      AppPage.activities => ActivitiesScreen(
        key: ValueKey('activities-${access.role}-$activityContextId'),
        navigation: access,
        initialPage: activityPage,
        activityId: activityContextId,
        onNavigate: _openPage,
      ),
      _ => ManagementScreen(
        key: ValueKey('${access.role}-${selected.name}'),
        index: selected.screenIndex,
        activityId: selected == AppPage.checkIn ? checkInActivityId : null,
        onNavigate: _openPage,
        title: context.tr(access.titleFor(selected)),
      ),
    };

    return Scaffold(
      key: _scaffoldKey,
      drawer: wide ? null : Drawer(width: 238, child: _sidebar(access)),
      body: Row(
        children: [
          if (wide) _sidebar(access),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 62,
                  padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      if (!wide)
                        IconButton(
                          key: const ValueKey('open-navigation'),
                          tooltip: context.tr('เปิดเมนู'),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
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
                      const LanguageSwitcher(),
                      if (access.isStudent && !mustChangePassword)
                        StudentActivityAlerts(
                          automaticallyShow: selected != AppPage.checkIn,
                          onOpenActivity: (id) =>
                              _openPage(AppPage.activityDetails, id),
                        ),
                      if (MediaQuery.sizeOf(context).width >= 650) ...[
                        if (!access.isStudent)
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
                                    .firstOrNull
                                    ?.toUpperCase() ??
                                'U',
                            style: const TextStyle(color: Color(0xFF1265E8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user['full_name']?.toString() ??
                              context.tr('ผู้ใช้งาน'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'logout') {
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
                            _selectPage(AppPage.password);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'password',
                            child: Text(context.tr('เปลี่ยนรหัสผ่าน')),
                          ),
                          PopupMenuItem(
                            value: 'logout',
                            child: Text(context.tr('ออกจากระบบ')),
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
      bottomNavigationBar: wide || pages.length < 2
          ? null
          : NavigationBar(
              selectedIndex: pages.contains(selected)
                  ? pages.indexOf(selected)
                  : 0,
              onDestinationSelected: (index) => _selectPage(pages[index]),
              destinations: [
                for (final item in pages)
                  NavigationDestination(
                    key: ValueKey('bottom-${item.name}'),
                    icon: Icon(item.icon),
                    label: context.tr(switch (item) {
                      AppPage.overview => 'ภาพรวม',
                      AppPage.points => 'คะแนนสะสม',
                      _ => item.title,
                    }),
                  ),
              ],
            ),
    );
  }

  Widget _sidebar(AppNavigation access) => SizedBox(
    width: 238,
    child: Material(
      color: const Color(0xFF102A4C),
      child: SafeArea(
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
              child: ListView(
                children: [
                  for (final item
                      in (mustChangePassword
                          ? [AppPage.password]
                          : access.primaryPages))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      child: ListTile(
                        key: ValueKey('sidebar-${item.name}'),
                        dense: true,
                        selected: selected == item,
                        selectedTileColor: const Color(0xFF2366A7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(item.icon, color: Colors.white, size: 19),
                        title: Text(
                          context.tr(access.titleFor(item)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => _selectPage(item),
                      ),
                    ),
                ],
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
      ),
    ),
  );
}
