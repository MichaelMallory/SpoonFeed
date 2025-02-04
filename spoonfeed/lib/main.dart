import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'utils/firebase_config.dart';
import 'firebase_options.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/profile_setup/profile_setup_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/config_service.dart';

// Initialize logger for debugging
final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.initialize();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseConfig.configureEmulators();
    logger.i('Firebase initialized successfully');
  } catch (e) {
    logger.e('Failed to initialize Firebase: $e');
  }
  
  runApp(const SpoonFeedApp());
}

class SpoonFeedApp extends StatelessWidget {
  const SpoonFeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpoonFeed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/auth': (context) => const AuthScreen(),
        '/profile-setup': (context) => const ProfileSetupScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/main': (context) => const MainScreen(),
        '/upload': (context) => const UploadScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // Simulated splash delay
      
      if (!mounted) return;
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if user has completed their profile
        final authService = AuthService();
        final userData = await authService.getUserData(user.uid);
        
        if (!mounted) return;
        
        if (userData?.displayName == null || userData?.bio == null) {
          logger.i('User profile incomplete, navigating to profile setup');
          Navigator.of(context).pushReplacementNamed('/profile-setup');
        } else {
          logger.i('User profile complete, navigating to main');
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } else {
        // Navigate to onboarding if user is not logged in
        logger.i('User is not logged in, navigating to onboarding');
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } catch (e) {
      logger.e('Error checking auth state: $e');
      // On error, default to onboarding
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'SpoonFeed',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

