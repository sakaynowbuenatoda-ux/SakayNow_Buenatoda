import 'package:flutter/material.dart';

import '../../core/preferences/app_preferences_controller.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class AppPreferencesPage extends StatefulWidget {
  const AppPreferencesPage({super.key});

  @override
  State<AppPreferencesPage> createState() => _AppPreferencesPageState();
}

class _AppPreferencesPageState extends State<AppPreferencesPage> {
  final AppPreferencesController _controller =
      AppPreferencesController.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: PassengerUi.background,
          appBar: AppBar(
            backgroundColor: PassengerUi.surface,
            surfaceTintColor: PassengerUi.surface,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
            ),
            title: Text('App Preferences', style: PassengerUi.cardTitle),
          ),
          body: PassengerPageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'App Preferences',
                  style: PassengerUi.sectionTitle.copyWith(fontSize: 22),
                ),
                SizedBox(height: 8),
                Text(
                  'Adjust appearance, language, and reading size preferences for the app experience.',
                  style: PassengerUi.bodyText,
                ),
                SizedBox(height: 18),
                _PreferenceGroupCard<AppThemePreference>(
                  title: 'Appearance',
                  subtitle: 'Choose how the interface should look.',
                  icon: Icons.light_mode_rounded,
                  accentColor: PassengerUi.primary,
                  options: const <_PreferenceOption<AppThemePreference>>[
                    _PreferenceOption(
                      value: AppThemePreference.light,
                      title: 'Light Mode',
                      subtitle:
                          'Bright surfaces and the current clean UI look.',
                      icon: Icons.light_mode_rounded,
                    ),
                    _PreferenceOption(
                      value: AppThemePreference.dark,
                      title: 'Dark Mode',
                      subtitle: 'A darker interface for lower-light viewing.',
                      icon: Icons.dark_mode_rounded,
                    ),
                  ],
                  selectedValue: _controller.themePreference,
                  onChanged: (value) {
                    _controller.setThemePreference(value);
                  },
                ),
                SizedBox(height: 14),
                _PreferenceGroupCard<AppLanguagePreference>(
                  title: 'Language',
                  subtitle: 'Select the preferred app language.',
                  icon: Icons.translate_rounded,
                  accentColor: PassengerUi.accentBlue,
                  options: const <_PreferenceOption<AppLanguagePreference>>[
                    _PreferenceOption(
                      value: AppLanguagePreference.english,
                      title: 'English',
                      subtitle: 'Use English across labels and interface text.',
                      icon: Icons.language_rounded,
                    ),
                    _PreferenceOption(
                      value: AppLanguagePreference.filipino,
                      title: 'Filipino',
                      subtitle:
                          'Use Filipino for the app interface when available.',
                      icon: Icons.flag_rounded,
                    ),
                  ],
                  selectedValue: _controller.languagePreference,
                  onChanged: (value) {
                    _controller.setLanguagePreference(value);
                  },
                ),
                SizedBox(height: 14),
                _PreferenceGroupCard<AppFontSizePreference>(
                  title: 'Display Font Size',
                  subtitle: 'Adjust text size for easier reading.',
                  icon: Icons.text_fields_rounded,
                  accentColor: PassengerUi.secondary,
                  options: const <_PreferenceOption<AppFontSizePreference>>[
                    _PreferenceOption(
                      value: AppFontSizePreference.small,
                      title: 'Small',
                      subtitle: 'More content fits on screen at once.',
                      icon: Icons.format_size_rounded,
                    ),
                    _PreferenceOption(
                      value: AppFontSizePreference.medium,
                      title: 'Medium',
                      subtitle: 'Current UI size and recommended default.',
                      icon: Icons.text_fields_rounded,
                    ),
                    _PreferenceOption(
                      value: AppFontSizePreference.large,
                      title: 'Large',
                      subtitle: 'Bigger text for easier readability.',
                      icon: Icons.title_rounded,
                    ),
                  ],
                  selectedValue: _controller.fontSizePreference,
                  onChanged: (value) {
                    _controller.setFontSizePreference(value);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreferenceGroupCard<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<_PreferenceOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  const _PreferenceGroupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[Text(title, style: PassengerUi.cardTitle)],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...options.asMap().entries.map(
            (MapEntry<int, _PreferenceOption<T>> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == options.length - 1 ? 0 : 10,
              ),
              child: _PreferenceChoiceTile<T>(
                option: entry.value,
                accentColor: accentColor,
                isSelected: entry.value.value == selectedValue,
                onTap: () => onChanged(entry.value.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceChoiceTile<T> extends StatelessWidget {
  final _PreferenceOption<T> option;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _PreferenceChoiceTile({
    required this.option,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.10)
              : PassengerUi.mutedSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : PassengerUi.border,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.16)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                option.icon,
                color: isSelected ? accentColor : PassengerUi.body,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    option.title,
                    style: PassengerUi.valueText.copyWith(
                      color: isSelected ? accentColor : PassengerUi.title,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? accentColor : PassengerUi.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceOption<T> {
  final T value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _PreferenceOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
