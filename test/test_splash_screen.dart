import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:zensort/screens/splash_screen.dart';
import 'package:zensort/widgets/animated_gradient_app_bar.dart';

void main() {
  testWidgets('SplashScreen shows spinning GradientLoader', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    // Verify the GradientLoader is present
    expect(find.byType(GradientLoader), findsOneWidget);
    // Optionally, check for the loader's size
    final loader = tester.widget<GradientLoader>(find.byType(GradientLoader));
    expect(loader.size, 80);
  });
}
