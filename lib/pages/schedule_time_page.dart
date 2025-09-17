import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:van_go/pages/seat_selection_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleTimePage extends StatelessWidget {
  final String from;
  final String to;
  final DateTime date;

  const ScheduleTimePage({
    required this.from,
    required this.to,
    required this.date,
    super.key,
  });

  String get routeId =>
      '${from.trim().toLowerCase()}_${to.trim().toLowerCase()}';

  Future<int> fetchPriceForRoute(String routeId) async {
    final doc = await FirebaseFirestore.instance
        .collection('routes')
        .doc(routeId)
        .get();
    if (doc.exists && doc.data()!.containsKey('pricePerSeat')) {
      return doc['pricePerSeat'];
    }
    return 0;
  }

  bool isTimeAvailable(String timeString) {
    final now = DateTime.now();
    final selectedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    // If the selected date is in the future, all times are available
    if (selectedDate.isAfter(today)) {
      return true;
    }

    // If the selected date is in the past, no times are available
    if (selectedDate.isBefore(today)) {
      return false;
    }

    // If it's today, check if the time has passed
    if (selectedDate.isAtSameMomentAs(today)) {
      try {
        // Parse the time string (e.g., "4:00 PM" or "16:00")
        final timeFormat =
            timeString.contains('PM') || timeString.contains('AM')
            ? DateFormat('h:mm a')
            : DateFormat('HH:mm');

        final scheduleTime = timeFormat.parse(timeString);
        final scheduleDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          scheduleTime.hour,
          scheduleTime.minute,
        );

        // Add a buffer of 30 minutes (user cannot book if departure is within 30 minutes)
        final bufferTime = now.add(Duration(minutes: 30));

        return scheduleDateTime.isAfter(bufferTime);
      } catch (e) {
        print("Error parsing time: $timeString - $e");
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEE, MMM d, y').format(date);
    String queryDate = DateFormat('yyyy-MM-dd').format(date);

    print("DEBUG: routeId → $routeId | queryDate → $queryDate");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("$from → $to", style: TextStyle(fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Price Display
            FutureBuilder<int>(
              future: fetchPriceForRoute(routeId),
              builder: (context, priceSnapshot) {
                final price = priceSnapshot.data ?? 0;
                return Container(
                  padding: EdgeInsets.all(14),
                  margin: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(78, 78, 148, 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Price: $price ฿/seat",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Date Box
            Container(
              padding: EdgeInsets.all(14),
              margin: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Color.fromRGBO(207, 207, 232, 1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Color.fromRGBO(78, 78, 143, 1),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 20),
                  SizedBox(width: 10),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Schedules
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('schedules')
                    .where('routeId', isEqualTo: routeId)
                    .where('date', isEqualTo: queryDate)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No schedules available for this date.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  // Filter out past times for today
                  final availableDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final time = data['time'];
                    return isTimeAvailable(time);
                  }).toList();

                  print(
                    "DEBUG: Fetched ${docs.length} schedule(s), ${availableDocs.length} available",
                  );

                  if (availableDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No available schedules for this time.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Please select a future date or check back later.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 2.0,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    children: (() {
                      // Build a list of schedule items with all needed info
                      final items = availableDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final time = data['time'];
                        final seatsTotal = data['seatsTotal'];
                        final seatsTaken = List<int>.from(data['seatsTaken']);
                        final seatLeft = seatsTotal - seatsTaken.length;
                        final timeAvailable = isTimeAvailable(time);

                        return {
                          'doc': doc,
                          'data': data,
                          'time': time,
                          'seatsTotal': seatsTotal,
                          'seatsTaken': seatsTaken,
                          'seatLeft': seatLeft,
                          'timeAvailable': timeAvailable,
                        };
                      }).toList();

                      // Sort by time in chronological order
                      items.sort((a, b) {
                        try {
                          final timeFormat =
                              a['time'].contains('PM') ||
                                  a['time'].contains('AM')
                              ? DateFormat('h:mm a')
                              : DateFormat('HH:mm');

                          final timeA = timeFormat.parse(a['time']);
                          final timeB = timeFormat.parse(b['time']);

                          // Create DateTime objects for proper comparison
                          final dateTimeA = DateTime(
                            2000,
                            1,
                            1,
                            timeA.hour,
                            timeA.minute,
                          );
                          final dateTimeB = DateTime(
                            2000,
                            1,
                            1,
                            timeB.hour,
                            timeB.minute,
                          );

                          return dateTimeA.compareTo(dateTimeB);
                        } catch (e) {
                          print("Error sorting times: $e");
                          return 0;
                        }
                      });

                      // Map to widgets
                      return items.map((item) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: !item['timeAvailable']
                                ? Colors.grey[300]
                                : item['seatLeft'] > 0
                                ? Color.fromRGBO(207, 207, 232, 1)
                                : Colors.grey[200],
                            foregroundColor: !item['timeAvailable']
                                ? Colors.grey[600]
                                : item['seatLeft'] > 0
                                ? Colors.black
                                : Colors.grey,
                            side: BorderSide(
                              color: !item['timeAvailable']
                                  ? Colors.grey[400]!
                                  : Color.fromRGBO(78, 78, 143, 1),
                              width: 1.5,
                            ),
                          ),
                          onPressed:
                              item['timeAvailable'] && item['seatLeft'] > 0
                              ? () async {
                                  int price = await fetchPriceForRoute(routeId);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SeatSelectionPage(
                                        occupiedSeats: item['seatsTaken'],
                                        from: from,
                                        to: to,
                                        date: date,
                                        time: item['time'],
                                        pricePerSeat: price,
                                        location: routeId,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14.0,
                              horizontal: 10,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item['time'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  !item['timeAvailable']
                                      ? "Time Passed"
                                      : item['seatLeft'] > 0
                                      ? "Seat: ${item['seatLeft']} / ${item['seatsTotal']}"
                                      : "Full",
                                  style: TextStyle(
                                    color: !item['timeAvailable']
                                        ? Colors.grey[600]
                                        : item['seatLeft'] > 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList();
                    })(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
