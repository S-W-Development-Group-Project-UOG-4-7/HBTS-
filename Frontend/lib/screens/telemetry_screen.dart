import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip.dart';
import '../services/api_service.dart';

class TelemetryScreen extends StatefulWidget {
  final Trip trip;

  const TelemetryScreen({super.key, required this.trip});

  @override
  State<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen> {
  Position? currentPosition;
  bool isLoadingLocation = false;
  bool isSending = false;
  String statusMessage = 'Ready to send location';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isLoadingLocation = true);
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            statusMessage = 'Location permission denied';
            isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          statusMessage = 'Location permission permanently denied';
          isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPosition = position;
        statusMessage = 'Location acquired';
        isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error getting location: $e';
        isLoadingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sendTelemetry() async {
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location data available')),
      );
      return;
    }

    setState(() => isSending = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final success = await apiService.sendTelemetry(
        tripId: widget.trip.tripId,
        busId: widget.trip.busId ?? 1,
        lat: currentPosition!.latitude,
        lon: currentPosition!.longitude,
        speed: currentPosition!.speed,
        heading: currentPosition!.heading.toInt(),
      );

      setState(() {
        statusMessage = success ? 'Telemetry sent successfully!' : 'Failed to send telemetry';
        isSending = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusMessage),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error sending telemetry: $e';
        isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Send Telemetry"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Trip',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.trip.fromLocation} → ${widget.trip.toLocation}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trip #${widget.trip.tripId} • Bus #${widget.trip.busId ?? "N/A"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Location Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gps_fixed, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Current Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (isLoadingLocation)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (currentPosition != null) ...[
                      _buildLocationRow(
                        Icons.location_on,
                        'Latitude',
                        currentPosition!.latitude.toStringAsFixed(6),
                      ),
                      const SizedBox(height: 12),
                      _buildLocationRow(
                        Icons.location_on,
                        'Longitude',
                        currentPosition!.longitude.toStringAsFixed(6),
                      ),
                      const SizedBox(height: 12),
                      _buildLocationRow(
                        Icons.speed,
                        'Speed',
                        '${(currentPosition!.speed * 3.6).toStringAsFixed(2)} km/h',
                      ),
                      const SizedBox(height: 12),
                      _buildLocationRow(
                        Icons.explore,
                        'Heading',
                        '${currentPosition!.heading.toStringAsFixed(0)}°',
                      ),
                      const SizedBox(height: 12),
                      _buildLocationRow(
                        Icons.height,
                        'Altitude',
                        '${currentPosition!.altitude.toStringAsFixed(1)} m',
                      ),
                      const SizedBox(height: 12),
                      _buildLocationRow(
                        Icons.track_changes,
                        'Accuracy',
                        '±${currentPosition!.accuracy.toStringAsFixed(1)} m',
                      ),
                    ] else ...[
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              statusMessage,
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoadingLocation ? null : _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isSending || currentPosition == null) ? null : _sendTelemetry,
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send Telemetry Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status Card
            Card(
              color: statusMessage.contains('success')
                  ? Colors.green.shade50
                  : statusMessage.contains('Error') || statusMessage.contains('Failed')
                      ? Colors.red.shade50
                      : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      statusMessage.contains('success')
                          ? Icons.check_circle
                          : statusMessage.contains('Error') || statusMessage.contains('Failed')
                              ? Icons.error
                              : Icons.info,
                      color: statusMessage.contains('success')
                          ? Colors.green
                          : statusMessage.contains('Error') || statusMessage.contains('Failed')
                              ? Colors.red
                              : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String value) {
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
}
