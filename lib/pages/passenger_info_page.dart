import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:van_go/pages/payment_page.dart';

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
  List<String> condos = [];
  bool _loadingCondos = false;
  String? pickUpDropOffLocation;
  String? customCondoName;
  bool _isLoading = false;
  DocumentSnapshot? existingBooking;

  int get passengerCount => widget.selectedSeats.length;
  int get totalPrice => passengerCount * widget.pricePerSeat;

  @override
  void initState() {
    super.initState();
    if (showCondoDropdown) {
      _fetchCondos();
    }
  }

  Future<void> _fetchCondos() async {
    setState(() {
      _loadingCondos = true;
    });

    try {
      final QuerySnapshot condoSnapshot = await FirebaseFirestore.instance
          .collection('condos')
          .orderBy('name')
          .get();

      final List<String> fetchedCondos = condoSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
          .toList();

      // Add "Other" option at the end
      fetchedCondos.add("Other");

      setState(() {
        condos = fetchedCondos;
        _loadingCondos = false;
      });
    } catch (e) {
      print("Error fetching condos: $e");
      setState(() {
        // Fallback to hardcoded list if fetch fails
        condos = [
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
        _loadingCondos = false;
      });
    }
  }

  Future<bool> _checkForExistingBooking() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      final formattedBookingDate =
          "${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}";

      final existingBookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('from', isEqualTo: widget.from)
          .where('to', isEqualTo: widget.to)
          .where('date', isEqualTo: formattedBookingDate)
          .where('time', isEqualTo: widget.time)
          .get();

      if (existingBookings.docs.isNotEmpty) {
        existingBooking = existingBookings.docs.first;
        return true; // Duplicate found
      }
      return false; // No duplicate
    } catch (e) {
      print("Error checking existing bookings: $e");
      return false;
    }
  }

  void _showDuplicateBookingDialog() {
    final existingData = existingBooking!.data() as Map<String, dynamic>;
    final existingSeats = List<int>.from(existingData['selectedSeats'] ?? []);
    final existingPassengerCount = existingData['passengerCount'] ?? 0;

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
              Icon(Icons.info, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text("Duplicate Booking"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You already have a booking for this route, date, and time:",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Existing booking:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("• Seats: ${existingSeats.join(', ')}"),
                    Text("• Passengers: $existingPassengerCount"),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("New selection:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("• Seats: ${widget.selectedSeats.join(', ')}"),
                    Text("• Passengers: $passengerCount"),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                "These seats will be added to your existing booking when you proceed to payment.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset loading state and proceed to payment
                setState(() {
                  _isLoading = false;
                });
                _proceedToPaymentWithDuplicate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(78, 78, 148, 1),
                foregroundColor: Colors.white,
              ),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _proceedToPaymentWithDuplicate() {
    final existingData = existingBooking!.data() as Map<String, dynamic>;
    final existingSeats = List<int>.from(existingData['selectedSeats'] ?? []);
    final existingTotalPrice = existingData['totalPrice'] ?? 0;

    // Calculate combined data
    final combinedSeats = [...existingSeats, ...widget.selectedSeats].toSet().toList();
    final newTotalPrice = existingTotalPrice + totalPrice;

    // Determine final location
    String finalLocation = widget.location;
    if (showCondoDropdown && pickUpDropOffLocation != null) {
      if (pickUpDropOffLocation == "Other" && customCondoName != null) {
        finalLocation = customCondoName!.trim();
      } else {
        finalLocation = pickUpDropOffLocation!;
      }
    }

    // Navigate to payment page for duplicate booking
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          from: widget.from,
          to: widget.to,
          time: widget.time,
          date: widget.date,
          selectedSeats: combinedSeats, // All seats (for booking update)
          pricePerSeat: widget.pricePerSeat,
          totalPrice: newTotalPrice, // Total price for all seats (for booking update)
          location: finalLocation,
          existingBookingId: existingBooking!.id,
          isUpdatingExisting: true,
          newSeatsOnly: widget.selectedSeats, // Only the new seats selected
          newSeatsPrice: totalPrice, // Price for new seats only
        ),
      ),
    );
  }

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

                          // Show loading spinner while fetching condos
                          if (_loadingCondos)
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color.fromRGBO(78, 78, 148, 1),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Loading locations...",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
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
                    onPressed: _isLoading || (_loadingCondos && showCondoDropdown)
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

                            // Check for existing booking first
                            final hasDuplicate = await _checkForExistingBooking();
                            
                            if (hasDuplicate) {
                              // Show duplicate dialog, but after user clicks OK, proceed to payment
                              _showDuplicateBookingDialog();
                              return;
                            }

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

                            // Reset loading state
                            setState(() {
                              _isLoading = false;
                            });

                            // Navigate to PaymentPage
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentPage(
                                  from: widget.from,
                                  to: widget.to,
                                  time: widget.time,
                                  date: widget.date,
                                  selectedSeats: widget.selectedSeats,
                                  pricePerSeat: widget.pricePerSeat,
                                  totalPrice: totalPrice,
                                  location: finalLocation,
                                ),
                              ),
                            );
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
                        existingBooking != null 
                            ? "Updating your booking..."
                            : "Processing your booking...",
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