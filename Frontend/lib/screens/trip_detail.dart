import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import 'route_view.dart';
import 'booked_seats.dart';
import 'telemetry_screen.dart';

class TripDetailPage extends StatefulWidget {
  final Trip trip;

  const TripDetailPage({super.key, required this.trip});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  late Trip currentTrip;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    currentTrip = widget.trip;
  }

  Future<void> _startTrip() async {
    setState(() => isProcessing = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final success = await apiService.startTrip(currentTrip.tripId);

      if (success && mounted) {
        setState(() {
          currentTrip = Trip(
            tripId: currentTrip.tripId,
            routeId: currentTrip.routeId,
            routeName: currentTrip.routeName,
            fromLocation: currentTrip.fromLocation,
            toLocation: currentTrip.toLocation,
            tripDate: currentTrip.tripDate,
            departureTime: currentTrip.departureTime,
            arrivalTime: currentTrip.arrivalTime,
            status: 'running',
            driverId: currentTrip.driverId,
            busId: currentTrip.busId,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip started successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting trip: $e')),
        );
      }
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _endTrip() async {
    setState(() => isProcessing = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final success = await apiService.endTrip(currentTrip.tripId);

      if (success && mounted) {
        setState(() {
          currentTrip = Trip(
            tripId: currentTrip.tripId,
            routeId: currentTrip.routeId,
            routeName: currentTrip.routeName,
            fromLocation: currentTrip.fromLocation,
            toLocation: currentTrip.toLocation,
            tripDate: currentTrip.tripDate,
            departureTime: currentTrip.departureTime,
            arrivalTime: currentTrip.arrivalTime,
            status: 'completed',
            driverId: currentTrip.driverId,
            busId: currentTrip.busId,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip completed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending trip: $e')),
        );
      }
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: currentTrip.statusColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      currentTrip.status == 'running'
                          ? Icons.directions_bus
                          : currentTrip.status == 'completed'
                              ? Icons.check_circle
                              : Icons.schedule,
                      color: currentTrip.statusColor,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trip Status',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            currentTrip.statusDisplay,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: currentTrip.statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Route Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Route Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('From', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                currentTrip.fromLocation,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(Icons.more_vert, color: Colors.grey),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('To', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                currentTrip.toLocation,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.calendar_today, 'Date', dateFormat.format(currentTrip.tripDate)),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.access_time, 'Departure', timeFormat.format(currentTrip.departureTime)),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.access_time_filled, 'Arrival', timeFormat.format(currentTrip.arrivalTime)),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.confirmation_number, 'Trip ID', '#${currentTrip.tripId}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            if (currentTrip.status == 'scheduled')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isProcessing ? null : _startTrip,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Start Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),

            if (currentTrip.status == 'running') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isProcessing ? null : _endTrip,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.stop),
                  label: const Text('End Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelemetryScreen(trip: currentTrip),
                      ),
                    );
                  },
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Send Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              'View Route Stops',
              Icons.route,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RouteViewPage(tripId: currentTrip.tripId),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildActionCard(
              'View Booked Seats',
              Icons.event_seat,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookedSeatsPage(tripId: currentTrip.tripId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
