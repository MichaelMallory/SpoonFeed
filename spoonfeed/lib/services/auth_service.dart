import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/firebase_config.dart';

// Extension on UserModel for Firebase User conversion
extension UserModelExtension on UserModel {
  User toFirebaseUser() {
    return DummyUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoUrl,
    );
  }
}

class AuthService extends ChangeNotifier {
  final bool isEnabled;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn;
  final Logger _logger = Logger();
  User? _user;
  bool _isDevBypass = false;
  UserModel? _dummyUser;

  AuthService({
    this.isEnabled = true,
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  // Get current user
  User? get currentUser => _user;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _isDevBypass 
    ? Stream.value(_dummyUser?.toFirebaseUser())
    : _auth.authStateChanges();

  bool get isSignedIn => _isDevBypass || _user != null;

  // Development bypass method
  Future<UserModel> bypassAuthForDevelopment() async {
    _logger.w('⚠️ Using development authentication bypass');
    _isDevBypass = true;
    
    _dummyUser = UserModel(
      uid: 'dev-user-123',
      email: 'dev@example.com',
      username: 'DevUser',
      displayName: 'Development User',
      photoUrl: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isChef: true,
      bio: 'Development test account',
      followers: [],
      following: [],
      recipes: [],
    );

    notifyListeners();
    return _dummyUser!;
  }

  // Sign up with email and password
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      _logger.d('Starting email sign up process for email: $email');
      
      // Create auth user
      _logger.d('Creating Firebase Auth user...');
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw Exception('Failed to create user');
      _logger.d('Firebase Auth user created successfully with ID: ${user.uid}');

      // Wait for auth state to be ready and verify it matches
      await Future.delayed(const Duration(milliseconds: 500));
      if (_auth.currentUser?.uid != user.uid) {
        _logger.w('Auth state not ready or mismatch, waiting additional time...');
        await Future.delayed(const Duration(seconds: 1));
        
        // Final verification
        if (_auth.currentUser?.uid != user.uid) {
          throw Exception('Auth state verification failed');
        }
      }

      // Create user document in Firestore
      _logger.d('Creating Firestore user document...');
      final UserModel newUser = UserModel(
        uid: user.uid,
        email: email,
        username: username,
        displayName: username, // Set initial display name to username
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isChef: false, // Default value
        bio: '', // Default empty bio
        followers: [],
        following: [],
        recipes: [],
      );

      // Add retry mechanism for Firestore document creation
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(milliseconds: 500);

      while (retryCount < maxRetries) {
        try {
          final userDoc = _firestore.collection('users').doc(user.uid);
          
          // First check if document already exists
          final docSnapshot = await userDoc.get();
          if (docSnapshot.exists) {
            _logger.w('User document already exists, skipping creation');
            return UserModel.fromFirestore(docSnapshot);
          }

          // Create the document
          await userDoc.set(newUser.toMap());
          _logger.i('User document created successfully in Firestore');
          break;
        } catch (e) {
          retryCount++;
          _logger.w('Attempt $retryCount failed to create Firestore document: $e');
          
          if (e is FirebaseException) {
            if (e.code == 'permission-denied') {
              _logger.e('Permission denied creating user document. Error: ${e.message}');
              throw Exception('Permission denied creating user profile. Please try again.');
            }
          }
          
          if (retryCount == maxRetries) {
            _logger.e('Failed to create Firestore document after $maxRetries attempts');
            // Clean up auth user if we can't create Firestore document
            await user.delete().catchError((e) => _logger.e('Failed to delete auth user: $e'));
            throw Exception('Failed to create user profile. Please try again.');
          }
          
          await Future.delayed(retryDelay);
        }
      }
      
      _logger.i('User created successfully: ${user.uid}');
      return newUser;
    } catch (e) {
      _logger.e('Error signing up: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.d('Starting email sign in process for email: $email');
      
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw Exception('Failed to sign in');
      _logger.d('Firebase Auth sign in successful with ID: ${user.uid}');

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        _logger.w('User document not found, creating one...');
        // Create a basic user document if it doesn't exist - matching signup format
        final username = email.split('@')[0]; // Use email prefix as temporary username
        final UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          username: username,
          displayName: username, // Match signup by setting displayName
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isChef: false, // Default value
          bio: '', // Default empty bio
          followers: [],
          following: [],
          recipes: [],
        );
        
        // Use same retry mechanism as signup
        int retryCount = 0;
        const maxRetries = 3;
        const retryDelay = Duration(milliseconds: 500);

        while (retryCount < maxRetries) {
          try {
            await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
            _logger.i('Fallback user document created successfully');
            return newUser;
          } catch (e) {
            retryCount++;
            _logger.w('Attempt $retryCount failed to create fallback document: $e');
            
            if (e is FirebaseException && e.code == 'permission-denied') {
              _logger.e('Permission denied creating fallback document. Error: ${e.message}');
              throw Exception('Permission denied accessing user profile. Please try again.');
            }
            
            if (retryCount == maxRetries) {
              _logger.e('Failed to create fallback document after $maxRetries attempts');
              throw Exception('Failed to access user profile. Please try again.');
            }
            
            await Future.delayed(retryDelay);
          }
        }
      }

      _logger.i('User signed in successfully: ${user.uid}');
      return UserModel.fromFirestore(doc);
    } catch (e) {
      _logger.e('Error signing in: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _logger.i('User signed out successfully');
    } catch (e) {
      _logger.e('Error signing out: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _logger.i('Password reset email sent to: $email');
    } catch (e) {
      _logger.e('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      _logger.e('Error getting user data: $e');
      rethrow;
    }
  }

  // Update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      _logger.i('User data updated successfully: $uid');
    } catch (e) {
      _logger.e('Error updating user data: $e');
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    if (!isEnabled) {
      _logger.e('❌ Authentication is not available');
      throw Exception('Authentication is not available. Please check your internet connection and try again.');
    }

    try {
      _logger.i('🔄 Starting Google sign in process...');
      _logger.i('Firebase Auth state: ${_auth.currentUser != null ? 'Signed In' : 'Signed Out'}');
      _logger.i('Using emulator: ${FirebaseConfig.isUsingEmulator}');
      
      // Trigger the authentication flow
      _logger.i('📱 Launching Google Sign-In UI...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.w('⚠️ User cancelled Google sign in');
        return null;
      }
      _logger.i('✅ Google Sign-In successful for: ${googleUser.email}');

      // Obtain the auth details from the request
      _logger.i('🔑 Getting Google auth details...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      _logger.i('✅ Obtained Google auth tokens');

      // Create a new credential
      _logger.i('🔐 Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      _logger.i('✅ Firebase credential created');

      // Sign in to Firebase with the credential
      _logger.i('🔄 Signing in to Firebase with Google credential...');
      final UserCredential result = await _auth.signInWithCredential(credential);
      final User? user = result.user;
      if (user == null) throw Exception('Failed to sign in with Google');
      _logger.i('✅ Firebase sign in successful for user: ${user.uid}');

      // Check if this is a new user
      _logger.i('🔍 Checking if user exists in Firestore...');
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!doc.exists) {
        _logger.i('📝 Creating new user document for Google sign in...');
        // Create new user document
        final UserModel newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          username: user.displayName ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isChef: false,
          bio: '',
          followers: [],
          following: [],
          recipes: [],
        );

        try {
          await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
          _logger.i('✅ New user document created successfully');
          return newUser;
        } catch (e) {
          _logger.e('❌ Failed to create user document: $e');
          throw Exception('Failed to create user profile. Please try again.');
        }
      }

      _logger.i('✅ User signed in successfully with Google');
      return UserModel.fromFirestore(doc);
    } catch (e) {
      _logger.e('❌ Error signing in with Google: $e');
      if (e is FirebaseAuthException) {
        _logger.e('Firebase Auth Error Code: ${e.code}');
        _logger.e('Firebase Auth Error Message: ${e.message}');
        switch (e.code) {
          case 'account-exists-with-different-credential':
            throw Exception('An account already exists with a different sign-in method.');
          case 'invalid-credential':
            throw Exception('Invalid Google credentials. Please try again.');
          case 'operation-not-allowed':
            throw Exception('Google sign-in is not enabled. Please contact support.');
          case 'user-disabled':
            throw Exception('This account has been disabled. Please contact support.');
          default:
            throw Exception('Failed to sign in with Google. Please try again.');
        }
      }
      rethrow;
    }
  }
}

// Dummy User implementation for development
class DummyUser implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;

  DummyUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
  });

  @override
  Future<void> delete() async {}

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'dummy-token';

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    return DummyIdTokenResult();
  }

  @override
  bool get emailVerified => true;

  @override
  Future<void> reload() async {}

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? actionCodeSettings]) async {}

  @override
  Future<void> updateEmail(String newEmail) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> updatePhotoURL(String? photoURL) async {}

  @override
  Future<void> updateDisplayName(String? displayName) async {}

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail, [ActionCodeSettings? actionCodeSettings]) async {}

  @override
  String? get phoneNumber => null;

  @override
  String? get refreshToken => 'dummy-refresh-token';

  @override
  bool get isAnonymous => false;

  @override
  UserMetadata get metadata => DummyUserMetadata();

  @override
  List<UserInfo> get providerData => [];

  @override
  String get tenantId => 'dummy-tenant';

  @override
  MultiFactor get multiFactor => throw UnimplementedError();

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    throw UnimplementedError();
  }

  @override
  Future<ConfirmationResult> linkWithPhoneNumber(String phoneNumber, [RecaptchaVerifier? verifier]) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<void> linkWithRedirect(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> reauthenticateWithProvider(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<void> reauthenticateWithRedirect(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<User> unlink(String providerId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    throw UnimplementedError();
  }
}

// Dummy UserMetadata implementation for development
class DummyUserMetadata implements UserMetadata {
  @override
  DateTime? get creationTime => DateTime.now();

  @override
  DateTime? get lastSignInTime => DateTime.now();
}

// Dummy IdTokenResult implementation
class DummyIdTokenResult implements IdTokenResult {
  @override
  Map<String, dynamic> get claims => {};

  @override
  String get token => 'dummy-token';

  @override
  DateTime get authTime => DateTime.now();

  @override
  DateTime get issuedAtTime => DateTime.now();

  @override
  DateTime get expirationTime => DateTime.now().add(const Duration(hours: 1));

  @override
  String get signInProvider => 'password';

  @override
  String? get signInSecondFactor => null;
} 