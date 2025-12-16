import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:talkies_mobile/services/audio_recorder_service.dart';
import 'package:talkies_mobile/services/settings_service.dart';
import 'package:talkies_mobile/screens/home_screen.dart';
import 'package:talkies_mobile/theme/app_theme.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app with providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AudioRecorderService()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    // Verify app title appears in the app bar
    expect(find.text('Talkies'), findsOneWidget);

    // Verify recording button is present (mic icon for initial state)
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });
}
