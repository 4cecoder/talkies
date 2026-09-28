import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkies_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TalkiesApp());

    // Verify app title appears
    expect(find.text('Talkies Mobile'), findsOneWidget);
    
    // Verify recording button is present
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
