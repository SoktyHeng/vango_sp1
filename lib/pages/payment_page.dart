import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/stripe_config.dart';
import '../pages/navigator_page.dart';

class PaymentPage extends StatefulWidget {
  final String from;
  final String to;
  final String time;
  final DateTime date;
  final List<int> selectedSeats;
  final int pricePerSeat;
  final int totalPrice;
  final String location;
  final String? existingBookingId;
  final bool isUpdatingExisting;
  final List<int>? newSeatsOnly;
  final int? newSeatsPrice;

  const PaymentPage({
    super.key,
    required this.from,
    required this.to,
    required this.time,
    required this.date,
    required this.selectedSeats,
    required this.pricePerSeat,
    required this.totalPrice,
    required this.location,
    this.existingBookingId,
    this.isUpdatingExisting = false,
    this.newSeatsOnly,
    this.newSeatsPrice,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isProcessing = false;

  // Form controllers
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String get formattedDate =>
      "${widget.date.day}/${widget.date.month}/${widget.date.year}";

  List<int> get seatsToDisplay {
    return widget.isUpdatingExisting && widget.newSeatsOnly != null
        ? widget.newSeatsOnly!
        : widget.selectedSeats;
  }

  int get priceToDisplay {
    return widget.isUpdatingExisting && widget.newSeatsPrice != null
        ? widget.newSeatsPrice!
        : widget.totalPrice;
  }

  // Format card number with spaces
  String _formatCardNumber(String value) {
    value = value.replaceAll(' ', '');
    String formatted = '';
    for (int i = 0; i < value.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += value[i];
    }
    return formatted;
  }

  // Format expiry date
  String _formatExpiryDate(String value) {
    value = value.replaceAll('/', '');
    if (value.length >= 2) {
      return value.substring(0, 2) +
          '/' +
          value.substring(2, value.length > 4 ? 4 : value.length);
    }
    return value;
  }

  // Validate card with Stripe API using config file
  Future<Map<String, dynamic>> _validateCardWithStripe() async {
    try {
      // Parse expiry date
      List<String> expiryParts = _expiryController.text.split('/');
      if (expiryParts.length != 2) {
        return {'success': false, 'error': 'Invalid expiry date format'};
      }

      String expMonth = expiryParts[0].trim().padLeft(2, '0');
      String expYear = expiryParts[1].trim();
      if (expYear.length == 2) {
        expYear = '20$expYear';
      }

      print('Using Stripe key: ${StripeConfig.publishableKey}');

      // Create a payment method to validate the card
      final response = await http.post(
        Uri.parse(StripeConfig.paymentMethodsEndpoint),
        headers: {
          'Authorization': 'Bearer ${StripeConfig.publishableKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'type': 'card',
          'card[number]': _cardNumberController.text.replaceAll(' ', ''),
          'card[exp_month]': expMonth,
          'card[exp_year]': expYear,
          'card[cvc]': _cvvController.text,
          'billing_details[name]': _cardHolderController.text,
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Card is valid
        return {
          'success': true,
          'payment_method_id': data['id'],
          'card_brand': _formatCardBrand(data['card']['brand']),
          'last4': data['card']['last4'],
        };
      } else {
        // Card validation failed
        String errorMessage = 'Card validation failed';
        if (data['error'] != null) {
          switch (data['error']['code']) {
            case 'incorrect_number':
              errorMessage = 'Your card number is incorrect';
              break;
            case 'invalid_number':
              errorMessage = 'Your card number is not valid';
              break;
            case 'invalid_expiry_month':
              errorMessage = 'Invalid expiration month';
              break;
            case 'invalid_expiry_year':
              errorMessage = 'Invalid expiration year';
              break;
            case 'invalid_cvc':
              errorMessage = 'Invalid CVV/CVC code';
              break;
            case 'expired_card':
              errorMessage = 'Your card has expired';
              break;
            case 'card_declined':
              errorMessage = 'Your card was declined';
              break;
            default:
              errorMessage =
                  data['error']['message'] ?? 'Card validation failed';
          }
        }
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      print('Network error: $e');
      return {
        'success': false,
        'error': 'Network error: Please check your connection',
      };
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

  Future<void> _processPayment() async {
    // Validate form fields
    if (_cardNumberController.text.trim().isEmpty ||
        _cardHolderController.text.trim().isEmpty ||
        _expiryController.text.trim().isEmpty ||
        _cvvController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all card details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Validate card information with Stripe
      Map<String, dynamic> validationResult = await _validateCardWithStripe();

      if (!validationResult['success']) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationResult['error']),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // If card is valid, proceed with booking
      await _saveBooking(validationResult);

      setState(() {
        _isProcessing = false;
      });

      // Show success dialog
      _showSuccessDialog(validationResult);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      print("Payment validation error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to validate payment. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveBooking(Map<String, dynamic> validationResult) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final now = Timestamp.now();

    if (widget.isUpdatingExisting && widget.existingBookingId != null) {
      // Update existing booking - fetch driver info if not already stored
      String vanLicense = 'N/A';
      String driverPhone = 'N/A';
      
      // First check if the existing booking already has these details
      final existingBooking = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.existingBookingId!)
          .get();
      
      if (existingBooking.exists) {
        final existingData = existingBooking.data();
        vanLicense = existingData?['vanLicense'] ?? 'N/A';
        driverPhone = existingData?['driverPhone'] ?? 'N/A';
        
        // If details are not stored, fetch them from schedule
        if (vanLicense == 'N/A' || driverPhone == 'N/A') {
          final scheduleId = existingData?['scheduleId'];
          if (scheduleId != null) {
            final scheduleDoc = await FirebaseFirestore.instance
                .collection('schedules')
                .doc(scheduleId)
                .get();
            
            if (scheduleDoc.exists) {
              final scheduleData = scheduleDoc.data();
              vanLicense = scheduleData?['vanLicense'] ?? 'N/A';
              
              // Get driver phone from drivers collection using driverId
              final driverId = scheduleData?['driverId'];
              if (driverId != null) {
                try {
                  final driverDoc = await FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(driverId)
                      .get();
                  
                  if (driverDoc.exists) {
                    driverPhone = driverDoc.data()?['phoneNumber'] ?? 'N/A';
                  }
                } catch (e) {
                  print('Error fetching driver phone: $e');
                }
              }
            }
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.existingBookingId!)
          .update({
            'selectedSeats': widget.selectedSeats,
            'passengerCount': widget.selectedSeats.length,
            'totalPrice': widget.totalPrice,
            'location': widget.location,
            'timestamp': now,
            'paymentMethod': "stripe",
            'paymentStatus': "validated",
            'cardBrand': validationResult['card_brand'],
            'cardLast4': validationResult['last4'],
            'stripePaymentMethodId': validationResult['payment_method_id'],
            'vanLicense': vanLicense,
            'driverPhone': driverPhone,
          });

      // Update schedule seatsTaken (only add the NEW seats)
      if (widget.newSeatsOnly != null && widget.newSeatsOnly!.isNotEmpty) {
        await _updateScheduleSeats();
      }
    } else {
      // Create new booking
      final routeId = "${widget.from.toLowerCase()}_${widget.to.toLowerCase()}";
      final formattedBookingDate =
          "${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}";

      final scheduleQuery = await FirebaseFirestore.instance
          .collection('schedules')
          .where('routeId', isEqualTo: routeId)
          .where('date', isEqualTo: formattedBookingDate)
          .where('time', isEqualTo: widget.time)
          .limit(1)
          .get();

      if (scheduleQuery.docs.isEmpty) {
        throw Exception('Schedule not found');
      }

      final scheduleDoc = scheduleQuery.docs.first;
      final scheduleId = scheduleDoc.id;
      final scheduleData = scheduleDoc.data();
      
      // Get van license from schedule
      final vanLicense = scheduleData['vanLicense'] ?? 'N/A';
      
      // Get driver phone from drivers collection using driverId
      String driverPhone = 'N/A';
      final driverId = scheduleData['driverId'];
      if (driverId != null) {
        try {
          final driverDoc = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .get();
          
          if (driverDoc.exists) {
            driverPhone = driverDoc.data()?['phoneNumber'] ?? 'N/A';
          }
        } catch (e) {
          print('Error fetching driver phone: $e');
        }
      }

      // Create booking data
      final bookingData = {
        "from": widget.from,
        "to": widget.to,
        "date": formattedBookingDate,
        "time": widget.time,
        "selectedSeats": widget.selectedSeats,
        "pricePerSeat": widget.pricePerSeat,
        "totalPrice": widget.totalPrice,
        "passengerCount": widget.selectedSeats.length,
        "userId": userId,
        "timestamp": now,
        "location": widget.location,
        "scheduleId": scheduleId,
        "status": "confirmed",
        "paymentMethod": "stripe",
        "paymentStatus": "validated",
        "cardBrand": validationResult['card_brand'],
        "cardLast4": validationResult['last4'],
        "stripePaymentMethodId": validationResult['payment_method_id'],
        "vanLicense": vanLicense,
        "driverPhone": driverPhone,
      };

      await FirebaseFirestore.instance.collection('bookings').add(bookingData);

      // Update schedule seatsTaken
      final docRef = scheduleDoc.reference;
      final currentTaken = List<int>.from(scheduleDoc['seatsTaken'] ?? []);
      final updatedTaken = [...currentTaken, ...widget.selectedSeats];

      await docRef.update({"seatsTaken": updatedTaken.toSet().toList()});
    }
  }

  Future<void> _updateScheduleSeats() async {
    final routeId = "${widget.from.toLowerCase()}_${widget.to.toLowerCase()}";
    final formattedBookingDate =
        "${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}";

    final scheduleQuery = await FirebaseFirestore.instance
        .collection('schedules')
        .where('routeId', isEqualTo: routeId)
        .where('date', isEqualTo: formattedBookingDate)
        .where('time', isEqualTo: widget.time)
        .limit(1)
        .get();

    if (scheduleQuery.docs.isNotEmpty) {
      final scheduleDoc = scheduleQuery.docs.first;
      final currentTaken = List<int>.from(scheduleDoc['seatsTaken'] ?? []);
      final updatedTaken = [...currentTaken, ...widget.newSeatsOnly!];

      await scheduleDoc.reference.update({
        "seatsTaken": updatedTaken.toSet().toList(),
      });
    }
  }

  void _showSuccessDialog(Map<String, dynamic> validationResult) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text(
                'Card Validated Successfully',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isUpdatingExisting
                    ? 'Your seats have been added successfully!'
                    : 'Your booking has been confirmed successfully!',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue.shade600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Card validated via Stripe. No amount was charged.',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Card: **** **** **** ${validationResult['last4']} (${validationResult['card_brand']})',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScaffold()),
                  (route) => false,
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: Color.fromRGBO(78, 78, 148, 1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Payment',
          style: GoogleFonts.roboto(color: Colors.black87, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 15),

                // Booking Summary Card
                Card(
                  color: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: Color.fromRGBO(78, 78, 148, 1),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Booking Summary',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildSummaryRow(
                          'Route',
                          '${widget.from} → ${widget.to}',
                        ),
                        _buildSummaryRow('Date', formattedDate),
                        _buildSummaryRow('Time', widget.time),
                        _buildSummaryRow(
                          widget.isUpdatingExisting ? 'New Seats' : 'Seats',
                          seatsToDisplay.join(', '),
                        ),
                        _buildSummaryRow('Location', widget.location),
                        Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              '$priceToDisplay ฿',
                              style: GoogleFonts.roboto(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(78, 78, 148, 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 15),

                // Card Details Card
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.credit_card,
                              color: Color.fromRGBO(78, 78, 148, 1),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Card Details',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        _buildTextField(
                          controller: _cardNumberController,
                          label: 'Card Number',
                          keyboardType: TextInputType.number,
                          formatter: _formatCardNumber,
                          maxLength: 23,
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _cardHolderController,
                          label: 'Card Holder Name',
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _expiryController,
                                label: 'Expiry Date',
                                hintText: 'MM/YY',
                                keyboardType: TextInputType.datetime,
                                formatter: _formatExpiryDate,
                                maxLength: 5,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _cvvController,
                                label: 'CVV',
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                maxLength: 4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 80),
              ],
            ),
          ),

          // Loading Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromRGBO(78, 78, 148, 1),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Validating Card...',
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait while we validate your card with Stripe',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Floating Validate Card Button
      floatingActionButton: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 20),
        child: FloatingActionButton.extended(
          onPressed: _isProcessing ? null : _processPayment,
          backgroundColor: Color.fromRGBO(78, 78, 148, 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          label: Text(
            'Check Out',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.roboto(
              fontSize: 15,
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String Function(String)? formatter,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      style: TextStyle(fontSize: 16, color: Colors.black87),
      onChanged: formatter != null
          ? (value) {
              String formatted = formatter!(value);
              controller.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Color.fromRGBO(78, 78, 148, 1),
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: label == 'Card Number'
            ? Icon(Icons.credit_card, color: Colors.grey[400])
            : null,
        counterText: '',
      ),
    );
  }
}