import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import '../config/stripe_config.dart';

class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  // Validate card by creating a payment method (without charging)
  Future<StripeValidationResult> validateCard({
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvc,
    required String cardHolderName,
  }) async {
    try {
      // Create payment method using Stripe SDK
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(name: cardHolderName),
          ),
        ),
      );

      // If we reach here, the card is valid
      return StripeValidationResult(
        success: true,
        paymentMethodId: paymentMethod.id,
        cardBrand: paymentMethod.card?.brand ?? 'Unknown',
        last4: paymentMethod.card?.last4 ?? '',
      );
    } on StripeException catch (e) {
      // Handle Stripe-specific errors
      String errorMessage = 'Card validation failed';

      switch (e.error.code) {
        case 'incorrect_number':
          errorMessage = 'Your card number is incorrect';
          break;
        case 'invalid_number':
          errorMessage = 'Your card number is not a valid credit card number';
          break;
        case 'invalid_expiry_month':
          errorMessage = 'Your card\'s expiration month is invalid';
          break;
        case 'invalid_expiry_year':
          errorMessage = 'Your card\'s expiration year is invalid';
          break;
        case 'invalid_cvc':
          errorMessage = 'Your card\'s security code is invalid';
          break;
        case 'expired_card':
          errorMessage = 'Your card has expired';
          break;
        case 'incorrect_cvc':
          errorMessage = 'Your card\'s security code is incorrect';
          break;
        case 'card_declined':
          errorMessage = 'Your card was declined';
          break;
        case 'processing_error':
          errorMessage = 'An error occurred while processing your card';
          break;
        default:
          errorMessage = e.error.message ?? 'Card validation failed';
      }

      return StripeValidationResult(success: false, error: errorMessage);
    } catch (e) {
      return StripeValidationResult(
        success: false,
        error: 'Network error: Please check your connection and try again',
      );
    }
  }

  // Alternative method using direct API call (if you prefer more control)
  Future<StripeValidationResult> validateCardWithAPI({
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvc,
    required String cardHolderName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_methods'),
        headers: {
          'Authorization': 'Bearer ${StripeConfig.publishableKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'type': 'card',
          'card[number]': cardNumber.replaceAll(' ', ''),
          'card[exp_month]': expiryMonth.padLeft(2, '0'),
          'card[exp_year]': expiryYear.length == 2
              ? '20$expiryYear'
              : expiryYear,
          'card[cvc]': cvc,
          'billing_details[name]': cardHolderName,
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return StripeValidationResult(
          success: true,
          paymentMethodId: data['id'],
          cardBrand: _formatCardBrand(data['card']['brand']),
          last4: data['card']['last4'],
        );
      } else {
        String errorMessage = 'Card validation failed';
        if (data['error'] != null) {
          errorMessage = data['error']['message'] ?? errorMessage;
        }
        return StripeValidationResult(success: false, error: errorMessage);
      }
    } catch (e) {
      return StripeValidationResult(success: false, error: 'Network error: $e');
    }
  }

  // Create a payment intent for actual payment
  Future<StripeValidationResult> createPaymentIntent({
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvc,
    required String cardHolderName,
    required int amount, // in cents (e.g., 100 = $1.00)
    required String currency,
  }) async {
    try {
      // First, create payment method
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(name: cardHolderName),
          ),
        ),
      );

      // Create payment intent with the payment method
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer ${StripeConfig.secretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amount.toString(),
          'currency': currency.toLowerCase(),
          'payment_method': paymentMethod.id,
          'confirm': 'true',
          'automatic_payment_methods[enabled]': 'true',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return StripeValidationResult(
          success: true,
          paymentMethodId: paymentMethod.id,
          paymentIntentId: data['id'],
          cardBrand: paymentMethod.card?.brand ?? 'Unknown',
          last4: paymentMethod.card?.last4 ?? '',
        );
      } else {
        String errorMessage = 'Payment failed';
        if (data['error'] != null) {
          errorMessage = data['error']['message'] ?? errorMessage;
        }
        return StripeValidationResult(success: false, error: errorMessage);
      }
    } on StripeException catch (e) {
      return StripeValidationResult(
        success: false,
        error: e.error.message ?? 'Payment failed',
      );
    } catch (e) {
      return StripeValidationResult(success: false, error: 'Network error: $e');
    }
  }

  String _formatCardBrand(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return 'Visa';
      case 'mastercard':
        return 'Mastercard';
      case 'amex':
        return 'American Express';
      case 'discover':
        return 'Discover';
      case 'diners':
        return 'Diners Club';
      case 'jcb':
        return 'JCB';
      case 'unionpay':
        return 'UnionPay';
      default:
        return brand.toUpperCase();
    }
  }
}

class StripeValidationResult {
  final bool success;
  final String? error;
  final String? paymentMethodId;
  final String? paymentIntentId;
  final String? cardBrand;
  final String? last4;

  StripeValidationResult({
    required this.success,
    this.error,
    this.paymentMethodId,
    this.paymentIntentId,
    this.cardBrand,
    this.last4,
  });
}
