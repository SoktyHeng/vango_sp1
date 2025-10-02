import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:van_go/pages/navigator_page.dart';
import '../auth/auth_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  Future<bool> _checkUserExists(String uid) async {
    try {
      // Check if user document exists in Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      return userDoc.exists;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  Future<void> _signOutUser() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final user = snapshot.data!;
            
            return FutureBuilder<bool>(
              future: _checkUserExists(user.uid),
              builder: (context, userExistsSnapshot) {
                if (userExistsSnapshot.connectionState == ConnectionState.waiting) {
                  // Show loading while checking user existence
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                if (userExistsSnapshot.hasData && userExistsSnapshot.data == true) {
                  // User exists in database, show main app
                  return MainScaffold();
                } else {
                  // User doesn't exist in database, sign out and show auth page
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _signOutUser();
                  });
                  
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            );
          } else {
            // No authenticated user, show auth page
            return AuthPage();
          }
        },
      ),
    );
  }
}
