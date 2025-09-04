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

  Stream<List<Map<String, dynamic>>> getConsolidatedBookingsStream(bool upcoming) {
    DateTime now = DateTime.now();

    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          // Group bookings by route, date, and time
          Map<String, List<QueryDocumentSnapshot>> groupedBookings = {};
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final dateStr = data['date'];
            final timeStr = data['time'];
            final from = data['from'];
            final to = data['to'];
            
            if (dateStr == null || timeStr == null || from == null || to == null) continue;

            final fullDateTime = DateTime.tryParse('$dateStr $timeStr') ??
                _parseCustomDateTime(dateStr, timeStr);

            if (fullDateTime == null) continue;

            final bookingEndTime = fullDateTime.add(const Duration(hours: 1));
            final isUpcoming = bookingEndTime.isAfter(now);

            if (isUpcoming == upcoming) {
              // Create a unique key for grouping
              final key = '${from}_${to}_${dateStr}_${timeStr}';
              groupedBookings.putIfAbsent(key, () => []).add(doc);
            }
          }

          // Convert grouped bookings to consolidated format
          List<Map<String, dynamic>> consolidatedBookings = [];
          
          groupedBookings.forEach((key, docs) {
            if (docs.isNotEmpty) {
              // Use the first document as base
              final baseData = docs.first.data() as Map<String, dynamic>;
              
              // Consolidate all seats and calculate total
              Set<int> allSeats = {};
              int totalPassengers = 0;
              int totalPrice = 0;
              List<String> bookingIds = [];
              
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final seats = List<int>.from(data['selectedSeats'] ?? []);
                allSeats.addAll(seats);
                totalPassengers += (data['passengerCount'] ?? 0) as int;
                totalPrice += (data['totalPrice'] ?? 0) as int;
                bookingIds.add(doc.id);
              }

              // Create consolidated booking data
              final consolidatedData = Map<String, dynamic>.from(baseData);
              consolidatedData['selectedSeats'] = allSeats.toList()..sort();
              consolidatedData['passengerCount'] = totalPassengers;
              consolidatedData['totalPrice'] = totalPrice;
              consolidatedData['bookingIds'] = bookingIds;
              consolidatedData['isConsolidated'] = docs.length > 1;
              consolidatedData['originalBookingsCount'] = docs.length;
              
              consolidatedBookings.add(consolidatedData);
            }
          });

          // Sort by date and time
          consolidatedBookings.sort((a, b) {
            final dateTimeA = DateTime.tryParse('${a['date']} ${a['time']}') ??
                _parseCustomDateTime(a['date'], a['time']) ?? DateTime.now();
            final dateTimeB = DateTime.tryParse('${b['date']} ${b['time']}') ??
                _parseCustomDateTime(b['date'], b['time']) ?? DateTime.now();
            
            return upcoming 
                ? dateTimeA.compareTo(dateTimeB)  // Ascending for upcoming
                : dateTimeB.compareTo(dateTimeA); // Descending for past
          });

          return consolidatedBookings;
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
      final isPM = timeParts.length > 1 && timeParts[1].toLowerCase() == 'pm';

      int hour = timeNumbers[0];
      int minute = timeNumbers[1];

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return DateTime(dateParts[0], dateParts[1], dateParts[2], hour, minute);
    } catch (_) {
      return null;
    }
  }

  Widget buildBookingCard(Map<String, dynamic> data) {
    final date = data['date'] ?? '';
    final time = data['time'] ?? '';
    final from = data['from'] ?? '';
    final to = data['to'] ?? '';
    final seatsList = data['selectedSeats'];
    final seats = seatsList is List ? seatsList.join(', ') : 'N/A';
    final totalPrice = data['totalPrice'] ?? 0;
    final isConsolidated = data['isConsolidated'] ?? false;
    final originalBookingsCount = data['originalBookingsCount'] ?? 1;
    final passengerCount = data['passengerCount'] ?? 0;

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
                  Expanded(
                    child: Text(
                      "$from → $to",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kColorDeep,
                      ),
                    ),
                  ),
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

              // Consolidated booking indicator
              if (isConsolidated) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.merge_type,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Consolidated ($originalBookingsCount bookings)",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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

              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.airline_seat_recline_normal,
                      "Seats",
                      seats,
                      Colors.indigo.shade600,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.people,
                      "Passengers",
                      passengerCount.toString(),
                      Colors.teal.shade600,
                    ),
                  ),
                ],
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getConsolidatedBookingsStream(upcoming),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "My Booking",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
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