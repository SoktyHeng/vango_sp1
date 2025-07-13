import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PassengerInfoPage extends StatefulWidget {
  final String from;
  final String to;
  final String time;
  final DateTime date;
  final List<int> selectedSeats;
  final int pricePerSeat;
  final String location;

  const PassengerInfoPage({
    super.key,
    required this.from,
    required this.to,
    required this.time,
    required this.date,
    required this.selectedSeats,
    this.pricePerSeat = 0,
    required this.location,
  });

  @override
  State<PassengerInfoPage> createState() => _PassengerInfoPageState();
}

class _PassengerInfoPageState extends State<PassengerInfoPage> {
  final TextEditingController _promoController = TextEditingController();
  bool _isLoading = false; // Add this loading state

  int get passengerCount => widget.selectedSeats.length;
  int get totalPrice => passengerCount * widget.pricePerSeat;

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        "${widget.date.day}/${widget.date.month}/${widget.date.year}";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Booking Summary", style: TextStyle(fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip Details Card
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.route,
                              color: Colors.blue.shade600,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Trip Details",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Route
                        _buildInfoRow(
                          Icons.location_on,
                          "${widget.from} → ${widget.to}",
                        ),
                        SizedBox(height: 12),

                        // Date & Time
                        _buildInfoRow(Icons.calendar_today, formattedDate),
                        SizedBox(height: 8),
                        _buildInfoRow(Icons.access_time, widget.time),
                        SizedBox(height: 12),

                        // Seats
                        _buildInfoRow(
                          Icons.airline_seat_recline_normal,
                          "Seats: ${widget.selectedSeats.join(', ')} ($passengerCount passenger${passengerCount > 1 ? 's' : ''})",
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Price Breakdown Card
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt,
                              color: Colors.green.shade600,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Price Breakdown",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("$passengerCount × ${widget.pricePerSeat} ฿"),
                            Text(
                              "$totalPrice ฿",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),

                        Divider(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "$totalPrice ฿",
                              style: TextStyle(
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

                SizedBox(height: 20),

                // Promo Code Card
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              color: Colors.orange.shade600,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Promo Code",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        TextField(
                          controller: _promoController,
                          decoration: InputDecoration(
                            hintText: "Enter promo code (optional)",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color.fromRGBO(78, 78, 148, 1),
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 50),

                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              final userId = user?.uid;
                              final now = Timestamp.now();

                              final bookingData = {
                                "from": widget.from,
                                "to": widget.to,
                                "date":
                                    "${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}",
                                "time": widget.time,
                                "selectedSeats": widget.selectedSeats,
                                "pricePerSeat": widget.pricePerSeat,
                                "totalPrice":
                                    widget.selectedSeats.length *
                                    widget.pricePerSeat,
                                "passengerCount": widget.selectedSeats.length,
                                "promoCode": _promoController.text.trim(),
                                "userId": userId,
                                "timestamp": now,
                                "location": widget.location,
                              };

                              // Save booking
                              await FirebaseFirestore.instance
                                  .collection('bookings')
                                  .add(bookingData);

                              // Update schedule seatTaken
                              final routeId =
                                  "${widget.from.toLowerCase()}_${widget.to.toLowerCase()}";
                              final scheduleQuery = await FirebaseFirestore
                                  .instance
                                  .collection('schedules')
                                  .where('routeId', isEqualTo: routeId)
                                  .where('date', isEqualTo: bookingData['date'])
                                  .where('time', isEqualTo: widget.time)
                                  .limit(1)
                                  .get();

                              if (scheduleQuery.docs.isNotEmpty) {
                                final scheduleDoc = scheduleQuery.docs.first;
                                final docRef = scheduleDoc.reference;

                                final currentTaken = List<int>.from(
                                  scheduleDoc['seatsTaken'],
                                );
                                final updatedTaken = [
                                  ...currentTaken,
                                  ...widget.selectedSeats,
                                ];

                                await docRef.update({
                                  "seatsTaken": updatedTaken.toSet().toList(),
                                });
                              }

                              setState(() {
                                _isLoading = false;
                              });

                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text("Booking Confirmed"),
                                  content: Text("Your booking has been saved."),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.popUntil(
                                        context,
                                        (route) => route.isFirst,
                                      ),
                                      child: Text("OK"),
                                    ),
                                  ],
                                ),
                              );
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });

                              print("Booking error: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Failed to save booking. Please try again.",
                                  ),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(78, 78, 148, 1),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            "Check Out",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Full screen loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24),
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
                      SizedBox(height: 16),
                      Text(
                        "Processing your booking...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method for info rows
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}
