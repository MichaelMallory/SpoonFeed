import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';  // Add for runZonedGuarded
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';  // Add for connectivity check
import 'package:flutter_dotenv/flutter_dotenv.dart';  // Add for .env support
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
import 'services/game_service.dart';
import 'services/cookbook_service.dart';
import 'providers/cook_mode_provider.dart';
import 'services/cook_mode_camera_service.dart';
import 'services/cook_mode_permission_service.dart';
import 'services/gesture_recognition_service.dart';
import 'utils/cook_mode_logger.dart';
import 'services/voice_command_service.dart';
import 'providers/voice_control_provider.dart';
import 'screens/wake_word_test_screen.dart';
import 'services/video_player_service.dart';

// Add near the top of the file, after imports
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger for debugging
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
    ),
  );

  // Run app with error handling
  runZonedGuarded(() async {
    logger.i('🚀 Starting app initialization...');
    bool isFirebaseInitialized = false;
    SharedPreferences prefs;

    try {
      // Step 1: Initialize shared preferences
      logger.i('💾 Initializing SharedPreferences...');
      prefs = await SharedPreferences.getInstance();
      logger.i('✅ SharedPreferences initialized');
    } catch (e) {
      logger.e('❌ SharedPreferences initialization failed: $e');
      rethrow;
    }

    // Step 2: Load environment variables
    try {
      logger.i('🔧 Loading environment variables...');
      await ConfigService.initialize();
      logger.i('✅ Environment variables loaded');
    } catch (e) {
      logger.e('❌ Environment variables loading failed: $e');
      logger.w('⚠️ App may have limited functionality');
    }

    // Step 3: Initialize Firebase
    try {
      logger.i('🔥 Initializing Firebase...');
      
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        
        // Wait for Firebase to be ready
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verify Firebase is initialized
        if (Firebase.apps.isEmpty) {
          throw Exception('Firebase initialization verification failed');
        }
        
        isFirebaseInitialized = true;
        logger.i('✅ Firebase initialized successfully');

        // Configure Emulators in Debug Mode
        if (kDebugMode) {
          logger.i('🧪 Configuring Firebase Emulators for debug mode...');
          await FirebaseConfig.configureEmulators();
          logger.i('✅ Firebase Emulators configured successfully');
        }
      } else {
        logger.i('✅ Firebase already initialized');
        isFirebaseInitialized = true;
      }
    } catch (e) {
      logger.e('❌ Firebase initialization failed: $e');
      isFirebaseInitialized = false;
    }

    // Log Firebase initialization status
    logger.i('Firebase initialization status: ${isFirebaseInitialized ? 'SUCCESS' : 'FAILED'}');
    if (!isFirebaseInitialized) {
      logger.w('⚠️ App will run with limited functionality due to Firebase initialization failure');
    }

    // Step 4: Run App with Proper Provider Setup
    logger.i('🏗️ Setting up app providers...');
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => GameService(),
            lazy: true,
          ),
          ChangeNotifierProvider(
            create: (_) => AuthService(isEnabled: isFirebaseInitialized),
            lazy: false,
          ),
          Provider(
            create: (_) => CookbookService(),
            lazy: true,
          ),
          ChangeNotifierProvider(
            create: (_) => VideoPlayerService(),
          ),
          ChangeNotifierProxyProvider<VideoPlayerService, VoiceCommandService>(
            create: (context) => VoiceCommandService(
              Provider.of<VideoPlayerService>(context, listen: false),
            ),
            update: (context, videoService, previous) => 
              previous ?? VoiceCommandService(videoService),
          ),
          ChangeNotifierProvider(
            create: (context) => VoiceControlProvider(
              Provider.of<VoiceCommandService>(context, listen: false),
            ),
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (context) => CookModeProvider(
              prefs,
              CookModeCameraService(),
              CookModePermissionService(),
              GestureRecognitionService(),
              context,
            ),
            lazy: false,
          ),
        ],
        child: SpoonFeedApp(isFirebaseEnabled: isFirebaseInitialized),
      ),
    );
    logger.i('✨ App initialization completed successfully');
    
  }, (error, stack) {
    logger.e('💥 Unhandled error in app: $error\n$stack');
  });
}

class SpoonFeedApp extends StatelessWidget {
  final bool isFirebaseEnabled;
  
  const SpoonFeedApp({
    super.key,
    required this.isFirebaseEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpoonFeed',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
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
        '/auth': (context) => AuthScreen(isFirebaseEnabled: isFirebaseEnabled),
        '/profile-setup': (context) => const ProfileSetupScreen(isInitialSetup: true),
        '/profile-edit': (context) => const ProfileSetupScreen(isInitialSetup: false),
        '/profile': (context) => ProfileScreen(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
        '/main': (context) => const MainScreen(),
        '/upload': (context) => const UploadScreen(),
        '/wake-word-test': (context) => const WakeWordTestScreen(),
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
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _logger.i('🎬 Starting splash screen sequence');
    _checkInitialRoute();
  }

  Future<void> _checkInitialRoute() async {
    try {
      _logger.i('⏳ Showing splash screen for 2 seconds');
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) {
        _logger.w('⚠️ Widget unmounted during splash delay');
        return;
      }

      // Check if user has completed onboarding
      _logger.i('🔍 Checking onboarding status');
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
      _logger.i('📱 Onboarding status: ${hasCompletedOnboarding ? 'completed' : 'not completed'}');

      if (!mounted) {
        _logger.w('⚠️ Widget unmounted during onboarding check');
        return;
      }

      if (!hasCompletedOnboarding) {
        _logger.i('🆕 New user detected - navigating to onboarding');
        Navigator.of(context).pushReplacementNamed('/onboarding');
        return;
      }

      // Only check auth state if onboarding is completed
      try {
        _logger.i('🔐 Checking authentication state');
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null) {
          _logger.i('👤 User authenticated: ${user.uid}');
          final authService = Provider.of<AuthService>(context, listen: false);
          
          _logger.i('📋 Fetching user profile data');
          final userData = await authService.getUserData(user.uid);
          
          if (!mounted) {
            _logger.w('⚠️ Widget unmounted during profile check');
            return;
          }
          
          if (userData?.displayName == null || userData?.bio == null) {
            _logger.i('⚠️ Incomplete profile detected - navigating to profile setup');
            Navigator.of(context).pushReplacementNamed('/profile-setup');
          } else {
            _logger.i('✅ Profile complete - navigating to main screen');
            Navigator.of(context).pushReplacementNamed('/main');
          }
        } else {
          _logger.i('🔒 No authenticated user - navigating to auth screen');
          Navigator.of(context).pushReplacementNamed('/auth');
        }
      } catch (e) {
        _logger.e('❌ Auth check failed: $e');
        if (mounted) {
          _logger.i('↩️ Falling back to onboarding screen');
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    } catch (e) {
      _logger.e('💥 Critical error during navigation check: $e');
      if (mounted) {
        _logger.i('↩️ Falling back to onboarding screen as safety measure');
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

