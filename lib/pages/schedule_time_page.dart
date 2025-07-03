import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:van_go/pages/seat_selection_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleTimePage extends StatelessWidget {
  final String from;
  final String to;
  final DateTime date;
  final String location;

  const ScheduleTimePage({
    required this.from,
    required this.to,
    required this.date,
    required this.location,
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

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEE, MMM d, y').format(date);
    String queryDate = DateFormat('yyyy-MM-dd').format(date); // for Firestore

    print("DEBUG: routeId → $routeId | queryDate → $queryDate");

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "$from → $to",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[700],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    return Center(child: Text("No schedules available."));
                  }

                  final docs = snapshot.data!.docs;
                  print("DEBUG: Fetched ${docs.length} schedule(s)");

                  for (var doc in docs) {
                    print("→ ${doc.data()}");
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 2.0,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final time = data['time'];
                      final seatsTotal = data['seatsTotal'];
                      final seatsTaken = List<int>.from(data['seatsTaken']);
                      final seatLeft = seatsTotal - seatsTaken.length;

                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Color.fromRGBO(207, 207, 232, 1),
                          foregroundColor: seatLeft > 0
                              ? Colors.black
                              : Colors.grey,
                          side: BorderSide(
                            color: Color.fromRGBO(78, 78, 143, 1),
                            width: 1.5,
                          ),
                        ),
                        onPressed: seatLeft > 0
                            ? () async {
                                int price = await fetchPriceForRoute(routeId);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SeatSelectionPage(
                                      occupiedSeats: seatsTaken,
                                      from: from,
                                      to: to,
                                      date: date,
                                      time: time,
                                      pricePerSeat: price,
                                      location: location,
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
                                time,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Seat: $seatLeft / $seatsTotal",
                                style: TextStyle(
                                  color: seatLeft > 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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

