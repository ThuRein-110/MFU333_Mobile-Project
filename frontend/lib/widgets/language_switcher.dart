import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.maybeOf(context);
    final selected = language?.locale.languageCode ?? 'th';
    final compact = MediaQuery.sizeOf(context).width < 650;
    return PopupMenuButton<String>(
      key: const ValueKey('language-switcher'),
      tooltip: context.tr('เปลี่ยนภาษา'),
      initialValue: selected,
      onSelected: (value) => language?.select(value),
      itemBuilder: (_) => [
        for (final entry in {'th': 'ไทย', 'en': 'English'}.entries)
          PopupMenuItem(
            value: entry.key,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: selected == entry.key
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                Text(entry.value),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 20),
            const SizedBox(width: 6),
            Text(
              compact
                  ? selected.toUpperCase()
                  : (selected == 'en' ? 'English' : 'ไทย'),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
