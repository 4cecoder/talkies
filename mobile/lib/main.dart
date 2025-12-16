import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/audio_recorder_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize settings
  final settingsService = SettingsService();
  await settingsService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioRecorderService()),
        ChangeNotifierProvider.value(value: settingsService),
      ],
      child: const TalkiesApp(),
    ),
  );
}

class TalkiesApp extends StatelessWidget {
  const TalkiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final isDarkMode = settingsService.settings.darkMode;

    return MaterialApp(
      title: 'Talkies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
