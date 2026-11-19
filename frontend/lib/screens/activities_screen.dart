import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../navigation/app_navigation.dart';
import 'management_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({
    super.key,
    required this.navigation,
    this.initialPage = AppPage.activities,
    this.activityId,
    this.onNavigate,
  });

  final AppNavigation navigation;
  final AppPage initialPage;
  final int? activityId;
  final void Function(AppPage page, int? activityId)? onNavigate;

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabs;
  late AppPage selected;
  int? activityId;

  @override
  void initState() {
    super.initState();
    final pages = widget.navigation.activityPages;
    selected = pages.contains(widget.initialPage)
        ? widget.initialPage
        : AppPage.activities;
    activityId = widget.activityId;
    tabs = TabController(
      length: pages.length,
      initialIndex: pages.indexOf(selected),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant ActivitiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage ||
        oldWidget.activityId != widget.activityId) {
      _open(widget.initialPage, widget.activityId);
    }
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  void _open(AppPage page, int? id) {
    final pages = widget.navigation.activityPages;
    if (!pages.contains(page)) {
      widget.onNavigate?.call(page, id);
      return;
    }
    setState(() {
      selected = page;
      activityId = id;
    });
    tabs.animateTo(pages.indexOf(page));
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.navigation.activityPages;
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) => _open(pages[index], activityId),
            tabs: [
              for (final page in pages)
                Tab(
                  key: ValueKey('activity-tab-${page.name}'),
                  text: context.tr(
                    page == AppPage.activities
                        ? 'รายการกิจกรรม'
                        : widget.navigation.titleFor(page),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ManagementScreen(
            key: ValueKey('activity-page-${selected.name}-$activityId'),
            index: selected.screenIndex,
            activityId: selected == AppPage.activities ? null : activityId,
            title: context.tr(widget.navigation.titleFor(selected)),
            onNavigate: _open,
          ),
        ),
      ],
    );
  }
}
