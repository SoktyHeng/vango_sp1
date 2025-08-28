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
  final List<String> condos = [
    "MSME",
    "King Solomon AU",
    "Queen of Sheba AU",
    "Dcondo",
    "Deeplus",
    "Viewpoint",
    "Tonson",
    "Groovy",
    "The Hub",
    "Swift Condo",
    "Muffin",
    "Delonix",
    "Other",
  ];

  String? pickUpDropOffLocation;
  String? customCondoName;
  bool _isLoading = false;

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

                // Condo Selection Card
                if (showCondoDropdown) ...[
                  SizedBox(height: 20),
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
                                Icons.location_city,
                                color: Colors.purple.shade600,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                condoLabel,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            dropdownColor: Colors.white,
                            value: pickUpDropOffLocation,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: "Select your location",
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
                            items: condos
                                .map(
                                  (condo) => DropdownMenuItem(
                                    value: condo,
                                    child: Text(condo),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                pickUpDropOffLocation = value;
                                if (value != "Other") {
                                  customCondoName = null;
                                }
                              });
                            },
                          ),

                          if (pickUpDropOffLocation == "Other")
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: TextFormField(
                                decoration: InputDecoration(
                                  hintText: "Enter your condo name",
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
                                onChanged: (value) {
                                  setState(() {
                                    customCondoName = value;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 50),

                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            // Validate condo selection if required
                            if (showCondoDropdown &&
                                (pickUpDropOffLocation == null ||
                                    (pickUpDropOffLocation == "Other" &&
                                        (customCondoName == null ||
                                            customCondoName!
                                                .trim()
                                                .isEmpty)))) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Please select your location"),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              final userId = user?.uid;
                              final now = Timestamp.now();

                              // First, find and get the schedule document to get its ID
                              final routeId =
                                  "${widget.from.toLowerCase()}_${widget.to.toLowerCase()}";
                              final formattedBookingDate =
                                  "${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}";

                              final scheduleQuery = await FirebaseFirestore
                                  .instance
                                  .collection('schedules')
                                  .where('routeId', isEqualTo: routeId)
                                  .where(
                                    'date',
                                    isEqualTo: formattedBookingDate,
                                  )
                                  .where('time', isEqualTo: widget.time)
                                  .limit(1)
                                  .get();

                              if (scheduleQuery.docs.isEmpty) {
                                throw Exception('Schedule not found');
                              }

                              final scheduleDoc = scheduleQuery.docs.first;
                              final scheduleId = scheduleDoc
                                  .id; // Get the schedule document ID

                              // Determine final location
                              String finalLocation = widget.location;
                              if (showCondoDropdown &&
                                  pickUpDropOffLocation != null) {
                                if (pickUpDropOffLocation == "Other" &&
                                    customCondoName != null) {
                                  finalLocation = customCondoName!.trim();
                                } else {
                                  finalLocation = pickUpDropOffLocation!;
                                }
                              }

                              // Create booking data with scheduleId
                              final bookingData = {
                                "from": widget.from,
                                "to": widget.to,
                                "date": formattedBookingDate,
                                "time": widget.time,
                                "selectedSeats": widget.selectedSeats,
                                "pricePerSeat": widget.pricePerSeat,
                                "totalPrice":
                                    widget.selectedSeats.length *
                                    widget.pricePerSeat,
                                "passengerCount": widget.selectedSeats.length,
                                "userId": userId,
                                "timestamp": now,
                                "location": finalLocation,
                                "scheduleId":
                                    scheduleId, // Add scheduleId field
                                "status": "confirmed", // Add booking status
                              };

                              // Save booking
                              await FirebaseFirestore.instance
                                  .collection('bookings')
                                  .add(bookingData);

                              // Update schedule seatsTaken
                              final docRef = scheduleDoc.reference;
                              final currentTaken = List<int>.from(
                                scheduleDoc['seatsTaken'] ?? [],
                              );
                              final updatedTaken = [
                                ...currentTaken,
                                ...widget.selectedSeats,
                              ];

                              await docRef.update({
                                "seatsTaken": updatedTaken.toSet().toList(),
                              });

                              setState(() {
                                _isLoading = false;
                              });

                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text("Booking Confirmed"),
                                  content: Text(
                                    "Your booking has been saved successfully.",
                                  ),
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

  // Add these getter methods
  bool get showCondoDropdown {
    return widget.from == "AU" || widget.to == "AU";
  }

  String get condoLabel {
    if (widget.from == "AU") {
      return "Pickup Location (Condo)";
    } else {
      return "Drop-off Location (Condo)";
    }
  }
}
