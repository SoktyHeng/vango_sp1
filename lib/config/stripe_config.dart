import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripeConfig {
  static String get publishableKey => dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  static String get secretKey => dotenv.env['STRIPE_SECRET_KEY'] ?? '';

  static const String paymentMethodsEndpoint = 'https://api.stripe.com/v1/payment_methods';
}