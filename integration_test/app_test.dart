import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deltaware/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Test', () {
    testWidgets('verify login screen renders and fails on bad credentials', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify Login Screen is showing
      expect(find.text('DELTAWARE'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      // Enter bad credentials
      await tester.enterText(find.byType(TextFormField).first, 'test@deltaware.dz');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpassword123');
      
      // Tap login button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Ensure error SnackBar is displayed
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
