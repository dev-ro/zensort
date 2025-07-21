import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zensort/widgets/google_sign_in_button.dart';
import 'package:mockito/mockito.dart';

class MockSignInHandler extends Mock {
  Future<void> call();
}

void main() {
  testWidgets(
    'GoogleSignInButton renders with Google logo and text, and triggers callback on tap',
    (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: () async {
                tapped = true;
                return Future.value();
              },
            ),
          ),
        ),
      );

      // Check for Google logo (by key)
      expect(find.byKey(const Key('google_logo')), findsOneWidget);
      // Check for correct text
      expect(find.text('Sign in with Google'), findsOneWidget);

      // Tap the button
      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    },
  );

  testWidgets('GoogleSignInButton triggers sign-in logic when tapped', (
    WidgetTester tester,
  ) async {
    final mockSignInHandler = MockSignInHandler();
    when(mockSignInHandler()).thenAnswer((_) async => Future.value());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GoogleSignInButton(onPressed: mockSignInHandler)),
      ),
    );
    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pumpAndSettle();
    verify(mockSignInHandler()).called(1);
  });
}
