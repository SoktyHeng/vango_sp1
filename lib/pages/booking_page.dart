import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:van_go/pages/booking_details_page.dart';

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

  Widget buildBookingCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = data['date'] ?? '';
    final time = data['time'] ?? '';
    final from = data['from'] ?? '';
    final to = data['to'] ?? '';
    final seatsList = data['selectedSeats'];
    final seats = seatsList is List ? seatsList.join(', ') : 'N/A';

    final totalPrice = data['totalPrice'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
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

              // Action Buttons
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingDetailPage(booking: data),
                        ),
                      );
                    },
                    icon: Icon(Icons.visibility, size: 18),
                    label: Text("View Details"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kColorDark,
                      side: BorderSide(color: kColorMid),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.map(buildBookingCard).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      appBar: AppBar(
        title: Text(
          "My Booking",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white10,
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
