import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';  // Add for runZonedGuarded
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';  // Add for connectivity check
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

// Initialize logger for debugging with custom printer for emojis
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 50,
    colors: true,
    printEmojis: true,
  ),
);

Future<void> main() async {
  await runZonedGuarded(() async {
    logger.i('🚀 Starting SpoonFeed initialization...');
    
    WidgetsFlutterBinding.ensureInitialized();
    logger.i('🎯 Flutter binding initialized');

    late final SharedPreferences prefs;
    bool isFirebaseInitialized = false;

    // Enable verbose logging for development
    CookModeLogger.verboseLogging = true;

    // Step 1: Initialize SharedPreferences
    try {
      logger.i('💾 Initializing SharedPreferences...');
      prefs = await SharedPreferences.getInstance();
      logger.i('✅ SharedPreferences initialized successfully');
    } catch (e) {
      logger.e('❌ Failed to initialize SharedPreferences: $e');
      logger.i('🔄 Falling back to mock SharedPreferences');
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    }

    // Step 2: Check Connectivity
    try {
      logger.i('🌐 Checking internet connectivity...');
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        logger.w('⚠️ No internet connection detected, some features may be limited');
      } else {
        logger.i('✅ Internet connection available: ${connectivity.toString()}');
      }
    } catch (e) {
      logger.w('⚠️ Failed to check connectivity: $e');
    }

    // Step 3: Initialize ConfigService
    try {
      logger.i('⚙️ Initializing ConfigService...');
      await ConfigService.initialize();
      logger.i('✅ ConfigService initialized successfully');
    } catch (e) {
      logger.e('❌ ConfigService initialization failed: $e');
      logger.w('⚠️ App may have limited functionality');
    }

    // Step 4: Initialize Firebase with timeout
    try {
      logger.i('🔥 Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          logger.e('⏰ Firebase initialization timed out');
          throw TimeoutException('Firebase initialization timed out');
        },
      );
      
      // Configure Emulators in Debug Mode
      if (kDebugMode) {
        logger.i('🧪 Configuring Firebase Emulators for debug mode...');
        await FirebaseConfig.configureEmulators();
        logger.i('✅ Firebase Emulators configured successfully');
      }
      
      isFirebaseInitialized = true;
      logger.i('✅ Firebase initialized successfully');
    } catch (e) {
      logger.e('❌ Firebase initialization failed: $e');
      isFirebaseInitialized = false;
    }

    // Step 5: Run App with Proper Provider Setup
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
            create: (_) => CookModeProvider(
              prefs,
              CookModeCameraService(),
              CookModePermissionService(),
              GestureRecognitionService(),
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
    // TODO: Add crash analytics reporting here
  });
}

class SpoonFeedApp extends StatelessWidget {
  final bool isFirebaseEnabled;
  static final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
  
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
    logger.i('🎬 Starting splash screen sequence');
    _checkInitialRoute();
  }

  Future<void> _checkInitialRoute() async {
    try {
      logger.i('⏳ Showing splash screen for 2 seconds');
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) {
        logger.w('⚠️ Widget unmounted during splash delay');
        return;
      }

      // Check if user has completed onboarding
      logger.i('🔍 Checking onboarding status');
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
      logger.i('📱 Onboarding status: ${hasCompletedOnboarding ? 'completed' : 'not completed'}');

      if (!mounted) {
        logger.w('⚠️ Widget unmounted during onboarding check');
        return;
      }

      if (!hasCompletedOnboarding) {
        logger.i('🆕 New user detected - navigating to onboarding');
        Navigator.of(context).pushReplacementNamed('/onboarding');
        return;
      }

      // Only check auth state if onboarding is completed
      try {
        logger.i('🔐 Checking authentication state');
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null) {
          logger.i('👤 User authenticated: ${user.uid}');
          final authService = Provider.of<AuthService>(context, listen: false);
          
          logger.i('📋 Fetching user profile data');
          final userData = await authService.getUserData(user.uid);
          
          if (!mounted) {
            logger.w('⚠️ Widget unmounted during profile check');
            return;
          }
          
          if (userData?.displayName == null || userData?.bio == null) {
            logger.i('⚠️ Incomplete profile detected - navigating to profile setup');
            Navigator.of(context).pushReplacementNamed('/profile-setup');
          } else {
            logger.i('✅ Profile complete - navigating to main screen');
            Navigator.of(context).pushReplacementNamed('/main');
          }
        } else {
          logger.i('🔒 No authenticated user - navigating to auth screen');
          Navigator.of(context).pushReplacementNamed('/auth');
        }
      } catch (e) {
        logger.e('❌ Auth check failed: $e');
        if (mounted) {
          logger.i('↩️ Falling back to onboarding screen');
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    } catch (e) {
      logger.e('💥 Critical error during navigation check: $e');
      if (mounted) {
        logger.i('↩️ Falling back to onboarding screen as safety measure');
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

