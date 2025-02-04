import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spoonfeed/screens/auth/auth_screen.dart';
import 'package:spoonfeed/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AuthService])
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    testWidgets('Sign in form validation works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(),
        ),
      );

      // Find the sign in button
      final signInButton = find.text('Sign In');
      await tester.tap(signInButton);
      await tester.pump();

      // Should show validation errors
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);

      // Fill in invalid email
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'invalid-email');
      await tester.tap(signInButton);
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('Sign up form validation works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(),
        ),
      );

      // Switch to sign up tab
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Find the sign up button
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pump();

      // Should show validation errors
      expect(find.text('Please enter a username'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('Forgot password dialog works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(),
        ),
      );

      // Open forgot password dialog
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);

      // Test validation
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);
    });
  });

  group('Device Compatibility Tests', () {
    testWidgets('Auth screen is responsive on different screen sizes',
        (WidgetTester tester) async {
      // Test on phone size
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Test on tablet size
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
} 