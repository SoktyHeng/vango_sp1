import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_details_page.dart';
import 'location_tracking_page.dart';
import 'qr_code_generator.dart'; // Add this import

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  final kColorLight = const Color(0xFFD4D2EB);
  final kColorMid = const Color(0xFFAAA6D4);
  final kColorPrimary = const Color(0xFF847FBE);
  final kColorDark = const Color(0xFF5F5CA7);
  final kColorDeep = const Color(0xFF3E3B8C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Stream<List<DocumentSnapshot>> getBookingsStream(bool upcoming) {
    DateTime now = DateTime.now();

    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            final dateStr = data['date']; // e.g. 2025-07-03
            final timeStr = data['time']; // e.g. 10:00 AM

            if (dateStr == null || timeStr == null) return false;

            final fullDateTime =
                DateTime.tryParse('$dateStr $timeStr') ??
                _parseCustomDateTime(dateStr, timeStr);

            if (fullDateTime == null) return false;

            final bookingEndTime = fullDateTime.add(const Duration(hours: 1));

            return upcoming
                ? bookingEndTime.isAfter(now)
                : bookingEndTime.isBefore(now);
          }).toList();
        });
  }

  DateTime? _parseCustomDateTime(String date, String time) {
    try {
      // Expected format: '2025-07-03' and '10:00 AM'
      final dateParts = date
          .split('-')
          .map(int.parse)
          .toList(); // [2025, 07, 03]
      final timeParts = time.split(' ');
      final timeNumbers = timeParts[0]
          .split(':')
          .map(int.parse)
          .toList(); // [10, 00]
      final isPM = timeParts[1].toLowerCase() == 'pm';

      int hour = timeNumbers[0];
      int minute = timeNumbers[1];

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return DateTime(dateParts[0], dateParts[1], dateParts[2], hour, minute);
    } catch (_) {
      return null;
    }
  }

  // Check if QR code is available for this booking
  bool _isQRCodeAvailable(Map<String, dynamic> bookingData) {
    final scheduleId = bookingData['scheduleId'];
    final status = bookingData['status'];

    // QR code is available if booking has scheduleId and is confirmed
    return scheduleId != null &&
        scheduleId.toString().isNotEmpty &&
        (status == 'confirmed' ||
            status == null); // null for backward compatibility
  }

  // Show QR code for the booking
  Future<void> _showQRCode(
    Map<String, dynamic> bookingData,
    String bookingId,
  ) async {
    try {
      // Get current user name
      final user = FirebaseAuth.instance.currentUser;
      String passengerName = 'Passenger';

      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            passengerName = userDoc.data()?['name'] ?? 'Passenger';
          }
        } catch (e) {
          print('Error getting user name: $e');
        }
      }

      // Navigate to QR code generator
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRCodeGenerator(
            bookingId: bookingId,
            scheduleId: bookingData['scheduleId'] ?? '',
            passengerName: passengerName,
            from: bookingData['from'] ?? '',
            to: bookingData['to'] ?? '',
            date: bookingData['date'] ?? '',
            time: bookingData['time'] ?? '',
            selectedSeats: List<dynamic>.from(
              bookingData['selectedSeats'] ?? [],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error showing QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading QR code. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // TEMPORARY TEST VERSION - Shows button for all bookings with scheduleId
  bool _isBookingTrackable(Map<String, dynamic> bookingData) {
    final scheduleId = bookingData['scheduleId'];
    print('Testing: Schedule ID = $scheduleId');

    // For testing - show button for any booking that has a scheduleId
    return scheduleId != null && scheduleId.toString().isNotEmpty;
  }

  Widget buildBookingCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bookingId = doc.id; // Get the document ID
    final date = data['date'] ?? '';
    final time = data['time'] ?? '';
    final from = data['from'] ?? '';
    final to = data['to'] ?? '';
    final seatsList = data['selectedSeats'];
    final seats = seatsList is List ? seatsList.join(', ') : 'N/A';
    final scheduleId = data['scheduleId'] ?? '';
    final totalPrice = data['totalPrice'] ?? 0;

    // Check if this booking is trackable and has QR code
    final isTrackable = _isBookingTrackable(data);
    final hasQRCode = _isQRCodeAvailable(data);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route Header
              Row(
                children: [
                  Text(
                    "$from → $to",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kColorDeep,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$totalPrice ฿",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Booking Details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.calendar_today,
                      "Date",
                      date,
                      Colors.orange.shade600,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.access_time,
                      "Time",
                      time,
                      Colors.purple.shade600,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              _buildDetailItem(
                Icons.airline_seat_recline_normal,
                "Seats",
                seats,
                Colors.indigo.shade600,
              ),

              SizedBox(height: 16),

              // Main Action Buttons - Single Row
              Row(
                children: [
                  // View Details Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingDetailPage(booking: data),
                          ),
                        );
                      },
                      icon: Icon(Icons.visibility_outlined, size: 16),
                      label: Text("Details"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  SizedBox(width: 8),

                  // QR Code Button (if available)
                  if (hasQRCode)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showQRCode(data, bookingId),
                        icon: Icon(Icons.qr_code_2, size: 16),
                        label: Text("Ticket"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kColorDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  // Track Button (if trackable)
                  if (isTrackable && scheduleId.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LocationTrackingPage(
                                scheduleId: scheduleId,
                                bookingData: data,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.location_on_outlined, size: 16),
                        label: Text("Track"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Remove the status indicators section completely or simplify to just one small indicator
              // if (hasQRCode || (isTrackable && scheduleId.isNotEmpty)) ...[
              //   SizedBox(height: 8),
              //   Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: [
              //       if (hasQRCode)
              //         Container(
              //           padding: EdgeInsets.symmetric(
              //             horizontal: 6,
              //             vertical: 2,
              //           ),
              //           decoration: BoxDecoration(
              //             color: kColorDark.withOpacity(0.1),
              //             borderRadius: BorderRadius.circular(4),
              //           ),
              //           child: Text(
              //             "Digital",
              //             style: TextStyle(
              //               fontSize: 10,
              //               color: kColorDark,
              //               fontWeight: FontWeight.w500,
              //             ),
              //           ),
              //         ),
              //       if (hasQRCode && (isTrackable && scheduleId.isNotEmpty))
              //         Container(
              //           margin: EdgeInsets.symmetric(horizontal: 4),
              //           width: 2,
              //           height: 2,
              //           decoration: BoxDecoration(
              //             color: Colors.grey[400],
              //             shape: BoxShape.circle,
              //           ),
              //         ),
              //       if (isTrackable && scheduleId.isNotEmpty)
              //         Container(
              //           padding: EdgeInsets.symmetric(
              //             horizontal: 6,
              //             vertical: 2,
              //           ),
              //           decoration: BoxDecoration(
              //             color: Colors.blue[50],
              //             borderRadius: BorderRadius.circular(4),
              //           ),
              //           child: Text(
              //             "Live",
              //             style: TextStyle(
              //               fontSize: 10,
              //               color: Colors.blue[700],
              //               fontWeight: FontWeight.w500,
              //             ),
              //           ),
              //         ),
              //     ],
              //   ),
              // ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildBookingsList(bool upcoming) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: getBookingsStream(upcoming),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade600,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Loading bookings...",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    upcoming ? Icons.event_available : Icons.history,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  "No ${upcoming ? "upcoming" : "past"} bookings",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  upcoming
                      ? "Your future trips will appear here"
                      : "Your booking history will appear here",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Sort bookings by date and time
        final sortedBookings = snapshot.data!
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aDateTime = _parseCustomDateTime(
              aData['date'] ?? '',
              aData['time'] ?? '',
            );
            final bDateTime = _parseCustomDateTime(
              bData['date'] ?? '',
              bData['time'] ?? '',
            );

            if (aDateTime == null && bDateTime == null) return 0;
            if (aDateTime == null) return 1;
            if (bDateTime == null) return -1;

            return upcoming
                ? aDateTime.compareTo(bDateTime) // Upcoming: earliest first
                : bDateTime.compareTo(aDateTime); // Past: latest first
          });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: sortedBookings.map(buildBookingCard).toList(),
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
          "My Bookings",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: kColorDeep,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: kColorDeep,
          indicatorWeight: 3,
          labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "Past"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [buildBookingsList(true), buildBookingsList(false)],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
