import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Logger _logger = Logger();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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

      // Create user document in Firestore
      _logger.d('Creating Firestore user document...');
      final UserModel newUser = UserModel(
        uid: user.uid,
        email: email,
        username: username,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _logger.d('Saving user document to Firestore...');
      await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      
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
        // Create a basic user document if it doesn't exist
        final UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          username: email.split('@')[0], // Use email prefix as temporary username
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        return newUser;
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
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential result = await _auth.signInWithCredential(credential);
      final User? user = result.user;
      if (user == null) throw Exception('Failed to sign in with Google');

      // Check if this is a new user
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // Create new user document
        final UserModel newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          username: user.displayName ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        _logger.i('New user created with Google: ${user.uid}');
        return newUser;
      }

      _logger.i('User signed in with Google: ${user.uid}');
      return UserModel.fromFirestore(doc);
    } catch (e) {
      _logger.e('Error signing in with Google: $e');
      rethrow;
    }
  }
} 