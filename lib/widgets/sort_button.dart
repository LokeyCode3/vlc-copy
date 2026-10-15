import 'package:flutter/material.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SortButton extends StatelessWidget {
  final SettingsProvider settings;
  const SortButton({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort_rounded),
      onSelected: (val) {
        if (val == settings.sortBy) {
          settings.setSortAscending(!settings.sortAscending);
        } else {
          settings.setSortBy(val);
        }
      },
      itemBuilder: (_) => [
        for (final opt in ['name', 'date', 'duration'])
          PopupMenuItem(
            value: opt,
            child: Row(children: [
              if (settings.sortBy == opt)
                Icon(
                  settings.sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: AppTheme.orange,
                ),
              if (settings.sortBy != opt) const SizedBox(width: 16),
              const SizedBox(width: 8),
              Text(opt[0].toUpperCase() + opt.substring(1)),
            ]),
          ),
      ],
    );
  }
}
