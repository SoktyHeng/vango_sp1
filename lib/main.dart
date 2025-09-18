import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'auth/main_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/stripe_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Stripe with the correct publishable key
  Stripe.publishableKey = StripeConfig.publishableKey;
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      home: MainPage(),
    );
  }
}