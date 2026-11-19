import 'package:flutter/material.dart';

enum AppPage {
  overview(0, 'ภาพรวม', Icons.dashboard_outlined),
  activities(1, 'กิจกรรม', Icons.event_note),
  activityDetails(2, 'รายละเอียดกิจกรรม', Icons.event),
  registrations(3, 'จัดการผู้ลงทะเบียน', Icons.groups),
  checkIn(4, 'เช็คอิน QR', Icons.qr_code_scanner),
  qrCodes(5, 'จัดการ QR Code', Icons.qr_code),
  points(13, 'ประวัติคะแนนสะสม', Icons.stars),
  users(14, 'บัญชีผู้ใช้', Icons.people),
  password(15, 'เปลี่ยนรหัสผ่าน', Icons.lock_reset),
  settings(16, 'ตั้งค่าระบบ', Icons.settings_outlined),
  studentDetails(17, 'รายละเอียดนักศึกษา', Icons.badge_outlined);

  const AppPage(this.screenIndex, this.title, this.icon);

  final int screenIndex;
  final String title;
  final IconData icon;
}

/// Navigation mirrors the API's role permissions. The API remains authoritative.
class AppNavigation {
  AppNavigation(String? role) : role = (role ?? '').trim().toLowerCase();

  final String role;

  bool get isStudent => role == 'student';
  bool get isLecturer => role == 'lecturer';
  bool get isAdmin => role == 'admin';
  bool get canManageActivities => isAdmin || isLecturer;
  bool get isKnownRole => isStudent || canManageActivities;

  List<AppPage> get primaryPages => [
    AppPage.overview,
    if (isKnownRole) AppPage.activities,
    if (canManageActivities) AppPage.studentDetails,
    if (isStudent) ...[AppPage.checkIn, AppPage.points],
    if (isAdmin) ...[AppPage.users, AppPage.settings],
  ];

  List<AppPage> get activityPages => [
    if (isKnownRole) ...[AppPage.activities, AppPage.activityDetails],
    if (isStudent || isLecturer) AppPage.registrations,
    if (canManageActivities) AppPage.qrCodes,
  ];

  String titleFor(AppPage page) {
    if (page == AppPage.overview) {
      if (isAdmin) return 'ภาพรวมระบบ';
      if (isLecturer) return 'ภาพรวมอาจารย์';
    }
    if (page == AppPage.registrations && isStudent) {
      return 'การลงทะเบียนของฉัน';
    }
    return page.title;
  }

  bool canOpenManagement(int index) {
    // The former standalone QR creation page uses the same staff permission.
    if (index == 6) return canManageActivities;
    return [
      ...primaryPages,
      ...activityPages,
    ].any((page) => page.screenIndex == index && page != AppPage.overview);
  }
}
