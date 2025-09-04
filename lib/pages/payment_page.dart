import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final List<int>? newSeatsOnly; // Add this to track only new seats
  final int? newSeatsPrice; // Add this to track price for new seats only

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
    this.newSeatsOnly, // Add this
    this.newSeatsPrice, // Add this
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

  // Get the seats to display (new seats only if updating, all seats if new booking)
  List<int> get seatsToDisplay {
    return widget.isUpdatingExisting && widget.newSeatsOnly != null
        ? widget.newSeatsOnly!
        : widget.selectedSeats;
  }

  // Get the price to display (new seats price only if updating, total price if new booking)
  int get priceToDisplay {
    return widget.isUpdatingExisting && widget.newSeatsPrice != null
        ? widget.newSeatsPrice!
        : widget.totalPrice;
  }

  Future<void> _processPayment() async {
    // Validate form fields
    if (_cardNumberController.text.trim().isEmpty ||
        _cardHolderController.text.trim().isEmpty ||
        _expiryController.text.trim().isEmpty ||
        _cvvController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all card details')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      final now = Timestamp.now();

      if (widget.isUpdatingExisting && widget.existingBookingId != null) {
        // Update existing booking with ALL seats (existing + new)
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.existingBookingId!)
            .update({
              'selectedSeats':
                  widget.selectedSeats, // All seats (existing + new)
              'passengerCount': widget.selectedSeats.length,
              'totalPrice': widget.totalPrice, // Total price for all seats
              'location': widget.location,
              'timestamp': now,
              'paymentMethod': "credit_card",
              'paymentStatus': "paid",
            });

        // Update schedule seatsTaken (only add the NEW seats)
        if (widget.newSeatsOnly != null && widget.newSeatsOnly!.isNotEmpty) {
          final routeId =
              "${widget.from.toLowerCase()}_${widget.to.toLowerCase()}";
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
            final currentTaken = List<int>.from(
              scheduleDoc['seatsTaken'] ?? [],
            );
            final updatedTaken = [...currentTaken, ...widget.newSeatsOnly!];

            await scheduleDoc.reference.update({
              "seatsTaken": updatedTaken.toSet().toList(),
            });
          }
        }
      } else {
        // Create new booking (existing logic)
        final routeId =
            "${widget.from.toLowerCase()}_${widget.to.toLowerCase()}";
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

        // Create booking data with scheduleId
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
          "paymentMethod": "credit_card",
          "paymentStatus": "paid",
        };

        // Save booking
        await FirebaseFirestore.instance
            .collection('bookings')
            .add(bookingData);

        // Update schedule seatsTaken
        final docRef = scheduleDoc.reference;
        final currentTaken = List<int>.from(scheduleDoc['seatsTaken'] ?? []);
        final updatedTaken = [...currentTaken, ...widget.selectedSeats];

        await docRef.update({"seatsTaken": updatedTaken.toSet().toList()});
      }

      setState(() {
        _isProcessing = false;
      });

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                widget.isUpdatingExisting
                    ? 'Seats Added'
                    : 'Payment Successful',
              ),
            ],
          ),
          content: Text(
            widget.isUpdatingExisting
                ? 'Additional seats have been added to your booking and payment processed successfully.'
                : 'Your booking has been confirmed and payment processed successfully.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(78, 78, 148, 1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      print("Payment error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to process payment. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Payment',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 20,
          ),
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
                          hintText: '1234 5678 9012 3456',
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _cardHolderController,
                          label: 'Card Holder Name',
                          hintText: 'John Doe',
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
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _cvvController,
                                label: 'CVV',
                                hintText: '123',
                                keyboardType: TextInputType.number,
                                obscureText: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 80), // Space for floating button
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
                        'Processing Payment...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait while we process your payment',
                        style: TextStyle(
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

      // Floating Pay Now Button
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
            'Pay Now',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          icon: Icon(Icons.payment, color: Colors.white),
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(fontSize: 16, color: Colors.black87),
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
      ),
    );
  }
}
