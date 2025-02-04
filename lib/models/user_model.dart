import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final bool isChef;
  final List<String> followers;
  final List<String> following;
  final List<String> recipes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.isChef = false,
    this.followers = const [],
    this.following = const [],
    this.recipes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      isChef: data['isChef'] ?? false,
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      recipes: List<String>.from(data['recipes'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'isChef': isChef,
      'followers': followers,
      'following': following,
      'recipes': recipes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? email,
    String? username,
    String? displayName,
    String? photoUrl,
    String? bio,
    bool? isChef,
    List<String>? followers,
    List<String>? following,
    List<String>? recipes,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      isChef: isChef ?? this.isChef,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      recipes: recipes ?? this.recipes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 