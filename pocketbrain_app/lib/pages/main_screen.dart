import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/settings_store.dart';
import '../widgets/sidebar.dart';

import 'ask_page.dart';
import 'library_page.dart';
import 'collections_page.dart';
import 'recent_page.dart';
import 'starred_page.dart';
import 'settings_page.dart';
import 'about_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final SettingsStore settings = SettingsStore.instance;

  static const List<String> pageNames = [
    'Ask',
    'Library',
    'Collections',
    'Recent',
    'Starred',
    'Settings',
    'About',
  ];

  String selectedPage = 'Ask';

  int get selectedPageIndex {
    final index = pageNames.indexOf(selectedPage);
    return index >= 0 ? index : 0;
  }

  @override
  void initState() {
    super.initState();

    settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);

    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void changePage(String page) {
    if (selectedPage == page) return;

    if (!pageNames.contains(page)) {
      debugPrint('Unknown navigation page: $page');
      return;
    }

    setState(() {
      selectedPage = page;
    });
  }

  Widget buildPageStack() {
    return IndexedStack(
      index: selectedPageIndex,
      sizing: StackFit.expand,
      children: const [
        AskPage(),
        LibraryPage(),
        CollectionsPage(),
        RecentPage(),
        StarredPage(),
        SettingsPage(),
        AboutPage(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(selectedPage: selectedPage, onPageSelected: changePage),

            Expanded(child: buildPageStack()),
          ],
        ),
      ),
    );
  }
}
