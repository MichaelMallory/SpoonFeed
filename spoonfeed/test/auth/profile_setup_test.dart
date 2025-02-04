import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spoonfeed/screens/auth/profile_setup_screen.dart';
import 'package:spoonfeed/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AuthService])
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Setup Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    testWidgets('Profile setup form validation works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );

      // Find the complete setup button
      final setupButton = find.text('Complete Setup');
      await tester.tap(setupButton);
      await tester.pump();

      // Should show validation errors
      expect(find.text('Please enter a display name'), findsOneWidget);
      expect(find.text('Please tell us a bit about yourself'), findsOneWidget);
    });

    testWidgets('Chef toggle switch works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );

      // Find and verify initial state of chef toggle
      final chefSwitch = find.byType(Switch);
      expect(tester.widget<Switch>(chefSwitch).value, false);

      // Toggle the switch
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      // Verify the switch is toggled
      expect(tester.widget<Switch>(chefSwitch).value, true);
    });
  });

  group('Device Compatibility Tests', () {
    testWidgets('Profile setup is responsive on different screen sizes',
        (WidgetTester tester) async {
      // Test on phone size
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify scrolling works on small screens
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      
      // Test text field visibility
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(SwitchListTile), findsOneWidget);

      // Test on tablet size
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all elements are still visible
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(SwitchListTile), findsOneWidget);
    });
  });
} 