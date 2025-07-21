import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zensort/screens/legal_screen.dart';

void main() {
  // Set up the mock asset bundle
  setUp(() {
    // This is a simplified mock. For more complex scenarios, you might need a more robust solution.
    // This mock intercepts the call to load a string from the asset bundle and returns a predefined string.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter/assets'), (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'loadString') {
            // You could make this more dynamic based on methodCall.arguments if needed
            return ByteData.sublistView(
              Uint8List.fromList('# Mock Markdown'.codeUnits),
            ).buffer.asByteData();
          }
          return null;
        });
  });

  // Clear the mock handler after the tests
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
  });

  testWidgets(
    'LegalScreen should display the correct title for privacy policy',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LegalScreen(docName: 'privacy_policy')),
      );
      await tester.pumpAndSettle(); // Wait for the asset to load
      expect(find.text('Privacy Policy'), findsOneWidget);
    },
  );

  testWidgets('LegalScreen should display the correct title for disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalScreen(docName: 'disclaimer')),
    );
    await tester.pumpAndSettle(); // Wait for the asset to load
    expect(find.text('Disclaimer'), findsOneWidget);
  });

  testWidgets(
    'LegalScreen should display the correct title for terms of service',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LegalScreen(docName: 'terms_of_service')),
      );
      await tester.pumpAndSettle(); // Wait for the asset to load
      expect(find.text('Terms of Service'), findsOneWidget);
    },
  );
}
