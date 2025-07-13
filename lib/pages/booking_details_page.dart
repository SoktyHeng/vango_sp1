import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookingDetailPage extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingDetailPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Booking Details',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Trip Information Card
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
                          const Icon(
                            Icons.route,
                            color: Color.fromRGBO(78, 78, 148, 1),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Trip Information',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _detailRow(Icons.location_on, "From", booking['from']),
                      _detailRow(Icons.flag, "To", booking['to']),
                      _detailRow(Icons.calendar_today, "Date", booking['date']),
                      _detailRow(Icons.access_time, "Time", booking['time']),
                      if (booking['location'] != null)
                        _detailRow(
                          Icons.place,
                          "Location",
                          booking['location'],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Booking Information Card
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
                          const Icon(
                            Icons.airline_seat_recline_normal,
                            color: Color.fromRGBO(78, 78, 148, 1),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Seat Details',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _detailRow(
                        Icons.event_seat,
                        "Seats",
                        (booking['selectedSeats'] as List).join(', '),
                      ),
                      _detailRow(
                        Icons.people,
                        "Passengers",
                        booking['passengerCount'].toString(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Payment Information Card
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
                          const Icon(
                            Icons.payment,
                            color: Color.fromRGBO(78, 78, 148, 1),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Payment Details',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _detailRow(
                        Icons.monetization_on,
                        "Price/Seat",
                        "${booking['pricePerSeat']} ฿",
                      ),
                      if ((booking['promoCode'] ?? "").isNotEmpty)
                        _detailRow(
                          Icons.local_offer,
                          "Promo Code",
                          booking['promoCode'],
                        ),
                      const Divider(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              "${booking['totalPrice']} ฿",
                              style: GoogleFonts.roboto(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color.fromRGBO(78, 78, 148, 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 15,
                color: Colors.grey[800],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
