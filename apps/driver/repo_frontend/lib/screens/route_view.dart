import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/route_stop.dart';
import '../services/api_service.dart';

class RouteViewPage extends StatefulWidget {
  final int tripId;

  const RouteViewPage({super.key, required this.tripId});

  @override
  State<RouteViewPage> createState() => _RouteViewPageState();
}

class _RouteViewPageState extends State<RouteViewPage> {
  List<RouteStop> stops = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRouteStops();
  }

  Future<void> _loadRouteStops() async {
    setState(() => isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final fetchedStops = await apiService.getRouteStops(widget.tripId);
      setState(() {
        stops = fetchedStops;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading route: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route Stops"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : stops.isEmpty
              ? Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                      Icon(Icons.route, size: 64, color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'No stops found for this route',
                        style: TextStyle(fontSize: 16, color: primaryColor),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRouteStops,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: stops.length,
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      final isFirst = index == 0;
                      final isLast = index == stops.length - 1;

                      return _buildStopItem(stop, isFirst, isLast);
                    },
                  ),
                ),
    );
  }

  Widget _buildStopItem(RouteStop stop, bool isFirst, bool isLast) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
              child: Center(
                child: Text(
                  '${stop.sequence}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Stop info card
        Expanded(
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.stopName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      if (isFirst)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'START',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isLast)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'END',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (stop.arrivalTime != null || stop.departureTime != null) ...[
                    Row(
                      children: [
                        if (stop.arrivalTime != null) ...[
                          Icon(Icons.login, size: 14, color: primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Arr: ${stop.arrivalTime}',
                            style: TextStyle(fontSize: 12, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (stop.departureTime != null) ...[
                          Icon(Icons.logout, size: 14, color: primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Dep: ${stop.departureTime}',
                            style: TextStyle(fontSize: 12, color: primaryColor),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${stop.lat.toStringAsFixed(6)}, ${stop.lon.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 11, color: primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
