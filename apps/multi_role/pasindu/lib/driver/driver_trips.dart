import 'package:flutter/material.dart';

class DriverTripsPage extends StatefulWidget {
  @override
  _DriverTripsPageState createState() => _DriverTripsPageState();
}

class _DriverTripsPageState extends State<DriverTripsPage> {
  String tripStatus = "Not Started";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Trips")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Route: Colombo → Kandy",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text("Status: $tripStatus"),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      tripStatus = "In Progress";
                    });
                  },
                  child: const Text("Start Trip"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      tripStatus = "Completed";
                    });
                  },
                  child: const Text("Complete Trip"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
