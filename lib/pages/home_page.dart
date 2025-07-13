import 'package:flutter/material.dart';
import 'schedule_time_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> locations = ["AU", "Mega", "Siam"];
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
    "Other", // Add 'Other' as last option
  ];
  String? fromLocation;
  String? toLocation;
  String? pickUpDropOffLocation;
  String? customCondoName; // For user input when "Other" is selected
  DateTime? departureDate;

  List<String> get filteredToLocations {
    if (fromLocation == null) return [];
    if (fromLocation == "AU") {
      return ["Mega", "Siam"];
    } else if (fromLocation == "Mega" || fromLocation == "Siam") {
      return ["AU"];
    } else {
      return locations.where((loc) => loc != fromLocation).toList();
    }
  }

  bool get showCondoDropdown {
    return fromLocation != null &&
        toLocation != null &&
        (fromLocation == "AU" || toLocation == "AU");
  }

  String get condoLabel {
    if (fromLocation == "AU") {
      return "Pickup Location (Condo)";
    } else {
      return "Drop-off Location (Condo)";
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

              // From Dropdown
              DropdownButtonFormField<String>(
                dropdownColor: Colors.white,
                value: fromLocation,
                isExpanded: true,
                decoration: InputDecoration(labelText: "From"),
                items: locations
                    .map(
                      (loc) => DropdownMenuItem(value: loc, child: Text(loc)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    fromLocation = value;
                    toLocation = null;
                    pickUpDropOffLocation = null;
                    customCondoName = null;
                  });
                },
              ),
              SizedBox(height: 20),

              // To Dropdown
              DropdownButtonFormField<String>(
                dropdownColor: Colors.white,
                value: toLocation,
                isExpanded: true,
                decoration: InputDecoration(labelText: "To"),
                items: filteredToLocations
                    .map(
                      (loc) => DropdownMenuItem(value: loc, child: Text(loc)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    toLocation = value;
                    pickUpDropOffLocation = null;
                    customCondoName = null;
                  });
                },
              ),
              SizedBox(height: 20),

              // Pick Up/Drop Off Location Dropdown (condos)
              if (showCondoDropdown)
                DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  value: pickUpDropOffLocation,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: condoLabel),
                  items: condos
                      .map(
                        (condo) =>
                            DropdownMenuItem(value: condo, child: Text(condo)),
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
              if (showCondoDropdown && pickUpDropOffLocation == "Other")
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: "Enter your condo name",
                    ),
                    onChanged: (value) {
                      setState(() {
                        customCondoName = value;
                      });
                    },
                  ),
                ),
              if (showCondoDropdown) SizedBox(height: 20),

              // Departure Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  departureDate == null
                      ? "Departure date"
                      : "Departure date: ${departureDate?.toLocal().toString().split(' ')[0]}",
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: departureDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() {
                      departureDate = picked;
                    });
                  }
                },
              ),
              SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Check if all required fields are filled
                    if (fromLocation != null &&
                        toLocation != null &&
                        departureDate != null &&
                        (!showCondoDropdown ||
                            (pickUpDropOffLocation != null &&
                                (pickUpDropOffLocation != "Other" ||
                                    (pickUpDropOffLocation == "Other" &&
                                        customCondoName != null &&
                                        customCondoName!.isNotEmpty))))) {
                      // All fields are filled, navigate to next page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScheduleTimePage(
                            from: fromLocation!,
                            to: toLocation!,
                            date: departureDate!,
                            location: pickUpDropOffLocation == "Other"
                                ? customCondoName!
                                : pickUpDropOffLocation!,
                          ),
                        ),
                      );
                    } else {
                      // Show a snackbar or dialog to inform user about missing fields
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please fill in all required fields'),
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
                  child: Text(
                    "Search",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
