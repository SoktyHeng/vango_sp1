import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'schedule_time_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> locations = [];
  String? fromLocation;
  String? toLocation;
  DateTime? departureDate;
  List<DateTime> availableDates = [];
  bool isLoadingDates = false;
  bool isLoadingLocations = true;

  // Add static cache
  static List<String>? _cachedLocations;
  static bool _hasLoadedLocations = false;

  @override
  void initState() {
    super.initState();
    fetchLocations();
  }

  // Modified fetchLocations with caching
  Future<void> fetchLocations() async {
    // Use cached data if available
    if (_hasLoadedLocations && _cachedLocations != null) {
      setState(() {
        locations = _cachedLocations!;
        isLoadingLocations = false;
      });
      return;
    }

    try {
      setState(() {
        isLoadingLocations = true;
      });

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('routes')
          .get();

      Set<String> locationSet = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String from = data['from'] ?? '';
        final String to = data['to'] ?? '';

        if (from.isNotEmpty) locationSet.add(from);
        if (to.isNotEmpty) locationSet.add(to);
      }

      final locationList = locationSet.toList()..sort();

      // Cache the results
      _cachedLocations = locationList;
      _hasLoadedLocations = true;

      setState(() {
        locations = locationList;
        isLoadingLocations = false;
      });
    } catch (e) {
      print('Error fetching locations: $e');

      // Cache fallback data too
      _cachedLocations = ["AU", "Mega", "Siam"];
      _hasLoadedLocations = true;

      setState(() {
        locations = _cachedLocations!;
        isLoadingLocations = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load locations. Using default options.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  List<String> get filteredToLocations {
    if (fromLocation == null) return [];

    // Get available destinations based on existing routes in Firebase
    return locations.where((loc) => loc != fromLocation).toList();
  }

  String get routeId {
    if (fromLocation == null || toLocation == null) return '';
    return '${fromLocation!.trim().toLowerCase()}_${toLocation!.trim().toLowerCase()}';
  }

  // Check if a route exists in the database
  Future<bool> checkRouteExists(String from, String to) async {
    try {
      final String routeId =
          '${from.trim().toLowerCase()}_${to.trim().toLowerCase()}';
      final doc = await FirebaseFirestore.instance
          .collection('routes')
          .doc(routeId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking route existence: $e');
      return false;
    }
  }

  // Fetch available dates for the selected route
  Future<void> fetchAvailableDates() async {
    if (fromLocation == null || toLocation == null) {
      setState(() {
        availableDates = [];
      });
      return;
    }

    // First check if the route exists
    final bool routeExists = await checkRouteExists(fromLocation!, toLocation!);
    if (!routeExists) {
      setState(() {
        availableDates = [];
        isLoadingDates = false;
        departureDate = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No route available from $fromLocation to $toLocation',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      isLoadingDates = true;
      availableDates = [];
      departureDate = null; // Reset selected date when route changes
    });

    try {
      final String currentRouteId = routeId;
      final DateTime now = DateTime.now();
      final DateTime maxDate = now.add(Duration(days: 90));

      // Query schedules for the selected route
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('routeId', isEqualTo: currentRouteId)
          .get();

      Set<DateTime> dateSet = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String dateStr = data['date'] ?? '';
        final String timeStr = data['time'] ?? '';

        if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
          try {
            // Parse the date string (format: yyyy-MM-dd)
            final DateTime scheduleDate = DateTime.parse(dateStr);

            // Only include future dates within the 90-day range
            if (scheduleDate.isAfter(now.subtract(Duration(days: 1))) &&
                scheduleDate.isBefore(maxDate.add(Duration(days: 1)))) {
              // Check if the time is still available (for today's date)
              if (scheduleDate.year == now.year &&
                  scheduleDate.month == now.month &&
                  scheduleDate.day == now.day) {
                // For today, check if the time hasn't passed
                if (isTimeAvailable(timeStr)) {
                  dateSet.add(scheduleDate);
                }
              } else if (scheduleDate.isAfter(now)) {
                // For future dates, add them
                dateSet.add(scheduleDate);
              }
            }
          } catch (e) {
            print('Error parsing date: $dateStr - $e');
          }
        }
      }

      setState(() {
        availableDates = dateSet.toList()..sort();
        isLoadingDates = false;
      });
    } catch (e) {
      print('Error fetching available dates: $e');
      setState(() {
        availableDates = [];
        isLoadingDates = false;
      });

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load available dates. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check if a time slot is still available (copied from schedule_time_page.dart)
  bool isTimeAvailable(String timeString) {
    final now = DateTime.now();

    try {
      // Parse the time string (e.g., "4:00 PM" or "16:00")
      final timeFormat = timeString.contains('PM') || timeString.contains('AM')
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

      // Add a buffer of 30 minutes
      final bufferTime = now.add(Duration(minutes: 30));
      return scheduleDateTime.isAfter(bufferTime);
    } catch (e) {
      print("Error parsing time: $timeString - $e");
      return false;
    }
  }

  // Custom date picker that only allows selection of available dates
  Future<void> showCustomDatePicker() async {
    if (availableDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No available schedules for this route.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final DateTime firstDate = availableDates.first;
    final DateTime lastDate = availableDates.last;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: departureDate ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime day) {
        // Only allow selection of dates that are in the availableDates list
        return availableDates.any(
          (date) =>
              date.year == day.year &&
              date.month == day.month &&
              date.day == day.day,
        );
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Color.fromRGBO(78, 78, 148, 1)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        departureDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo placeholder
              Image.asset('assets/logo.png', height: 100, width: 100),
              SizedBox(height: 32),

              // Show loading indicator while fetching locations
              // if (isLoadingLocations)
              //   Container(
              //     padding: EdgeInsets.all(16),
              //     decoration: BoxDecoration(
              //       border: Border.all(color: Colors.grey[300]!),
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: Row(
              //       children: [
              //         SizedBox(
              //           width: 20,
              //           height: 20,
              //           child: CircularProgressIndicator(
              //             strokeWidth: 2,
              //             valueColor: AlwaysStoppedAnimation<Color>(
              //               Color.fromRGBO(78, 78, 148, 1),
              //             ),
              //           ),
              //         ),
              //         SizedBox(width: 12),
              //         Text(
              //           'Loading available locations...',
              //           style: TextStyle(
              //             color: Colors.grey[600],
              //             fontSize: 16,
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),

              // From Dropdown
              if (!isLoadingLocations) ...[
                DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  value: fromLocation,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "From",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color.fromRGBO(78, 78, 148, 1),
                        width: 2,
                      ),
                    ),
                  ),
                  items: locations.isEmpty
                      ? []
                      : locations
                            .map(
                              (loc) => DropdownMenuItem(
                                value: loc,
                                child: Text(loc),
                              ),
                            )
                            .toList(),
                  onChanged: locations.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            fromLocation = value;
                            toLocation = null;
                            departureDate = null;
                            availableDates = [];
                          });
                        },
                ),
                SizedBox(height: 20),

                // To Dropdown
                DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  value: toLocation,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "To",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color.fromRGBO(78, 78, 148, 1),
                        width: 2,
                      ),
                    ),
                  ),
                  items: filteredToLocations
                      .map(
                        (loc) => DropdownMenuItem(value: loc, child: Text(loc)),
                      )
                      .toList(),
                  onChanged: fromLocation == null
                      ? null
                      : (value) async {
                          setState(() {
                            toLocation = value;
                            departureDate = null;
                          });

                          // Fetch available dates when both from and to are selected
                          if (fromLocation != null && toLocation != null) {
                            await fetchAvailableDates();
                          }
                        },
                ),
                SizedBox(height: 20),

                // Departure Date Picker
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      departureDate == null
                          ? "Select departure date"
                          : "Departure: ${departureDate?.toLocal().toString().split(' ')[0]}",
                      style: TextStyle(
                        fontSize: 16,
                        color: departureDate == null
                            ? Colors.grey[600]
                            : Colors.black87,
                      ),
                    ),
                    trailing: isLoadingDates
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color.fromRGBO(78, 78, 148, 1),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.calendar_today,
                            color: Color.fromRGBO(78, 78, 148, 1),
                          ),
                    enabled:
                        fromLocation != null &&
                        toLocation != null &&
                        !isLoadingDates,
                    onTap:
                        (fromLocation != null &&
                            toLocation != null &&
                            !isLoadingDates)
                        ? showCustomDatePicker
                        : null,
                  ),
                ),

                // Show available dates count
                if (fromLocation != null &&
                    toLocation != null &&
                    !isLoadingDates)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      availableDates.isEmpty
                          ? "No schedules available for this route"
                          : "${availableDates.length} date${availableDates.length != 1 ? 's' : ''} available",
                      style: TextStyle(
                        fontSize: 14,
                        color: availableDates.isEmpty
                            ? Colors.red[600]
                            : Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                SizedBox(height: 24),

                // Search Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoadingLocations
                        ? null
                        : () {
                            // Check if all required fields are filled
                            if (fromLocation != null &&
                                toLocation != null &&
                                departureDate != null) {
                              // All fields are filled, navigate to next page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScheduleTimePage(
                                    from: fromLocation!,
                                    to: toLocation!,
                                    date: departureDate!,
                                  ),
                                ),
                              );
                            } else {
                              // Show a snackbar to inform user about missing fields
                              String message = '';
                              if (fromLocation == null) {
                                message = 'Please select departure location';
                              } else if (toLocation == null) {
                                message = 'Please select destination';
                              } else if (departureDate == null) {
                                message = 'Please select departure date';
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(78, 78, 148, 1),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoadingLocations
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Loading...",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            "Search",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
