import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phone;
  final DateTime createdAt;

  User({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phone,
    required this.createdAt,
  });

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      uid: data['uid'],
      firstName: data['firstName'],
      lastName: data['lastName'],
      username: data['username'],
      email: data['email'],
      phone: data['phone'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'phone': phone,
      'createdAt': createdAt,
    };
  }
}