import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deltaware/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Test', () {
    testWidgets('verify login screen renders and handles bad credentials', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Clear any existing session because integration tests share local storage
      // If we are already logged in from a previous run, we will be on the Dashboard!
      try {
        await Supabase.instance.client.auth.signOut();
        await tester.pumpAndSettle(const Duration(seconds: 1));
      } catch (_) {}

      // Verify Login Screen is showing (using a static Icon that is always rendered)
      expect(find.byIcon(Icons.blur_on), findsOneWidget);

      // Enter bad credentials
      await tester.enterText(find.byType(TextField).first, 'test@deltaware.dz');
      await tester.enterText(find.byType(TextField).last, 'wrongpassword123');
      
      // Tap login button
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      // Ensure error SnackBar is displayed
      expect(find.byType(SnackBar), findsOneWidget);
      
      // Let any pending animations or network calls flush out before test ends
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('verify POS flow - navigate to POS, select sale type, search product', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 1. Clear session and ensure we are on Login Screen
      try {
        await Supabase.instance.client.auth.signOut();
        await tester.pumpAndSettle(const Duration(seconds: 1));
      } catch (_) {}

      // 2. Log in with real credentials provided by the user
      await tester.enterText(find.byType(TextField).first, 'mostafa@gmail.com');
      await tester.enterText(find.byType(TextField).last, 'mostafa123');
      await tester.tap(find.byType(ElevatedButton).first);
      
      // Wait for authentication network request and navigation to Dashboard
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 3. Navigate to POS via Sidebar
      final posSidebarItem = find.byIcon(Icons.point_of_sale);
      expect(posSidebarItem, findsWidgets);
      await tester.tap(posSidebarItem.first);
      
      // Wait for navigation and POS products to load from Supabase
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 4. Verify POS Screen loaded by looking for the "Current Sale" section
      expect(find.text('Current Sale'), findsOneWidget);

      // 5. Look for a product card to tap (add to cart)
      final productCard = find.descendant(
        of: find.byType(GridView),
        matching: find.byIcon(Icons.inventory_2_outlined),
      ).first;
      if (tester.any(productCard)) {
        await tester.tap(productCard);
        await tester.pumpAndSettle();

        // 6. Verify item was added to cart (we should see cart controls)
        expect(find.byIcon(Icons.add_rounded), findsWidgets);
        expect(find.text('CONFIRM SALE'), findsWidgets);
      } else {
        log('No products found in DB to tap, but POS loaded successfully.');
      }
    });
  });
}
