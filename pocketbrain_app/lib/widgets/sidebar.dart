
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/settings_store.dart';

class Sidebar extends StatefulWidget {
  final String selectedPage;
  final ValueChanged<String> onPageSelected;

  const Sidebar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final SettingsStore settings = SettingsStore.instance;

  @override
  void initState() {
    super.initState();
    settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  // =====================================================
  // NAVIGATION ITEM
  // =====================================================

  Widget navigationItem(
    String title,
    IconData icon,
    bool compact,
  ) {
    final bool isSelected = widget.selectedPage == title;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 2 : 3,
      ),
      child: Material(
        color: isSelected
            ? const Color(0xFF103C46)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            widget.onPageSelected(title);
          },
          borderRadius: BorderRadius.circular(9),
          hoverColor: AppColors.accent.withValues(
            alpha: 0.08,
          ),
          splashColor: AppColors.accent.withValues(
            alpha: 0.12,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 9 : 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: compact ? 18 : 20,
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.muted,
                ),
                SizedBox(width: compact ? 10 : 13),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.text
                          : AppColors.muted,
                      fontSize: compact ? 12 : 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // SECTION LABEL
  // =====================================================

  Widget sectionLabel(
    String title,
    bool compact,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: compact ? 18 : 25,
        top: compact ? 14 : 22,
        bottom: compact ? 6 : 10,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // =====================================================
  // LOCIQRA LOGO
  // =====================================================

  Widget buildLogo(bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        compact ? 22 : 30,
        compact ? 10 : 16,
        compact ? 16 : 22,
      ),
      child: Row(
        children: [
          Image.asset(
            'logo/lociqra logo.png',
            width: compact ? 27 : 32,
            height: compact ? 27 : 32,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return Icon(
                Icons.hub_outlined,
                color: AppColors.accent,
                size: compact ? 23 : 27,
              );
            },
          ),
          SizedBox(width: compact ? 8 : 11),
          Text(
            'LOCIQRA',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 16 : 19,
              fontWeight: FontWeight.bold,
              letterSpacing: compact ? 1.2 : 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SIDEBAR
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final compact = settings.compactMode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: compact ? 180 : 215,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(
          right: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // APP LOGO
          buildLogo(compact),

          const Divider(
            color: AppColors.border,
            height: 1,
          ),

          // NAVIGATION
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                vertical: compact ? 6 : 10,
              ),
              children: [
                sectionLabel(
                  'WORKSPACE',
                  compact,
                ),
                navigationItem(
                  'Ask',
                  Icons.auto_awesome_outlined,
                  compact,
                ),
                navigationItem(
                  'Library',
                  Icons.folder_open_outlined,
                  compact,
                ),
                navigationItem(
                  'Collections',
                  Icons.folder_copy_outlined,
                  compact,
                ),
                sectionLabel(
                  'PERSONAL',
                  compact,
                ),
                navigationItem(
                  'Recent',
                  Icons.history,
                  compact,
                ),
                navigationItem(
                  'Starred',
                  Icons.star_border,
                  compact,
                ),
                sectionLabel(
                  'APPLICATION',
                  compact,
                ),
                navigationItem(
                  'Settings',
                  Icons.settings_outlined,
                  compact,
                ),
                navigationItem(
                  'About',
                  Icons.info_outline,
                  compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
