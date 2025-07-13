import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  StreamSubscription<DocumentSnapshot>? _userDocListener;

  @override
  void initState() {
    super.initState();
    setupUserDocumentListener();
  }

  @override
  void dispose() {
    _userDocListener?.cancel();
    super.dispose();
  }

  void setupUserDocumentListener() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Listen to the user document in real-time
    _userDocListener = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (docSnapshot) {
            if (!mounted) return;

            if (docSnapshot.exists) {
              // Document exists, update user data
              setState(() {
                userData = docSnapshot.data();
                isLoading = false;
              });
            } else {
              // Document doesn't exist (deleted by admin)
              // Automatically sign out the user
              _handleUserDeleted();
            }
          },
          onError: (error) {
            print('Error listening to user document: $error');
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
        );
  }

  Future<void> _handleUserDeleted() async {
    try {
      // Sign out the user
      await FirebaseAuth.instance.signOut();

      // Show a message to inform the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been removed by an administrator.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error signing out deleted user: $e');
    }
  }

  Future<void> fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        userData = doc.data();
        isLoading = false;
      });
    } else {
      // Handle case where user document doesn't exist
      _handleUserDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If userData is null (user deleted), show loading while signing out
    if (userData == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Account removed. Signing out...'),
            ],
          ),
        ),
      );
    }

    final imageUrl = userData?['profileImage'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 25),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfilePage(),
                        ),
                      ).then((_) {
                        // Don't manually fetch data anymore since we're using real-time listener
                        // The listener will automatically update the UI
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: imageUrl != null
                      ? NetworkImage(imageUrl)
                      : null,
                  child: imageUrl == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  userData?['name'] ?? '',
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  userData?['email'] ?? '',
                  style: GoogleFonts.roboto(fontSize: 18),
                ),
                const SizedBox(height: 20),
                Text(
                  "Phone: ${userData?['phone number'] ?? 'N/A'}",
                  style: GoogleFonts.roboto(fontSize: 16),
                ),
                Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        FirebaseAuth.instance.signOut();
                      },
                      child: Text(
                        'Sign Out',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: const Color.fromRGBO(78, 78, 148, 1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Delete Account'),
                              content: const Text(
                                'Are you sure you want to delete your account?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final uid =
                                        FirebaseAuth.instance.currentUser!.uid;
                                    try {
                                      final imageRef = FirebaseStorage.instance
                                          .ref()
                                          .child('profile_images/$uid.jpg');
                                      await imageRef.delete();
                                    } catch (e) {
                                      // Image might not exist
                                    }
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .delete();
                                    await FirebaseAuth.instance.currentUser!
                                        .delete();
                                    if (!mounted) return;
                                    Navigator.of(context).pop();
                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Text(
                        'Delete Account',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: const Color.fromRGBO(78, 78, 148, 1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
