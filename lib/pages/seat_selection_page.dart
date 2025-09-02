import 'package:flutter/material.dart';
import 'package:van_go/pages/passenger_info_page.dart';
import 'package:intl/intl.dart'; // Add this import

class SeatSelectionPage extends StatefulWidget {
  final List<int> occupiedSeats;
  final String from;
  final String to;
  final DateTime date;
  final String time;
  final int pricePerSeat;
  final String location;

  const SeatSelectionPage({
    super.key,
    required this.occupiedSeats,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    this.pricePerSeat = 0,
    required this.location,
  });

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> {
  Set<int> selectedSeats = {};

  void handleNext(BuildContext context) {
    if (selectedSeats.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('No seat selected'),
          content: Text('Please select at least one seat.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PassengerInfoPage(
            from: widget.from,
            to: widget.to,
            time: widget.time,
            date: widget.date,
            selectedSeats: selectedSeats.toList(),
            pricePerSeat: widget.pricePerSeat,
            location: widget.location,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEE, MMM d, y').format(widget.date);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Select Seat', style: TextStyle(fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Time Info
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Color.fromRGBO(207, 207, 232, 1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color.fromRGBO(78, 78, 143, 1),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Colors.grey[700]),
                  SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 20),
                  Icon(Icons.access_time, size: 20, color: Colors.grey[700]),
                  SizedBox(width: 8),
                  Text(
                    widget.time,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Legend
            Row(
              children: [
                Checkbox(value: false, onChanged: null),
                Text('Available'),
                SizedBox(width: 16),
                Container(width: 20, height: 20, color: Colors.green),
                SizedBox(width: 4),
                Text('Selected'),
                SizedBox(width: 16),
                Container(width: 20, height: 20, color: Colors.red),
                SizedBox(width: 4),
                Text('Occupied'),
              ],
            ),
            SizedBox(height: 10),

            // Seat Grid
            Expanded(
              child: GridView.builder(
                itemCount: 12,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 36,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  int seatNumber = index + 1;
                  bool isOccupied = widget.occupiedSeats.contains(seatNumber);
                  bool isSelected = selectedSeats.contains(seatNumber);

                  Color bgColor = Colors.white;
                  if (isOccupied) {
                    bgColor = Colors.red;
                  } else if (isSelected) {
                    bgColor = Colors.green;
                  }

                  return GestureDetector(
                    onTap: isOccupied
                        ? null
                        : () {
                            setState(() {
                              if (isSelected) {
                                selectedSeats.remove(seatNumber);
                              } else {
                                selectedSeats.add(seatNumber);
                              }
                            });
                          },
                    child: Container(
                      margin: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '$seatNumber',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isOccupied ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Next Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Handle check out logic here
                  handleNext(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromRGBO(78, 78, 148, 1),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Next",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
