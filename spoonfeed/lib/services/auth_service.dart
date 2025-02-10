import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final bool isEnabled;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn;
  final Logger _logger = Logger();
  User? _user;

  AuthService({
    this.isEnabled = true,
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  // Get current user
  User? get currentUser => _user;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isSignedIn => _user != null;

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
  Future<UserCredential?> signInWithGoogle() async {
    if (!isEnabled) {
      throw Exception('Authentication is not available');
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      notifyListeners();
      return userCredential;
    } catch (e) {
      _logger.e('Google sign in failed: $e');
      rethrow;
    }
  }
} 