import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/route_stop.dart';
import '../services/api_service.dart';

class RouteMapPage extends StatefulWidget {
  final int tripId;

  const RouteMapPage({super.key, required this.tripId});

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  List<RouteStop> stops = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRouteStops();
  }

  Future<void> _loadRouteStops() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final fetchedStops = await apiService.getRouteStops(widget.tripId);
      if (!mounted) return;
      setState(() {
        stops = fetchedStops;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading route: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route Map"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRouteStops,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: primaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : stops.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 64, color: primaryColor),
                          const SizedBox(height: 16),
                          Text(
                            'No route stops available',
                            style: TextStyle(fontSize: 16, color: primaryColor),
                          ),
                        ],
                      ),
                    )
                  : _buildMap(),
    );
  }

  Widget _buildMap() {
    final points = stops.map((s) => LatLng(s.lat, s.lon)).toList();
    final start = points.first;

    return FlutterMap(
      options: MapOptions(
        initialCenter: start,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ["a", "b", "c"],
          userAgentPackageName: 'hbts_driver',
        ),
        if (points.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: Colors.blueAccent,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (int i = 0; i < points.length; i++)
              Marker(
                point: points[i],
                width: 42,
                height: 42,
                child: Tooltip(
                  message: stops[i].stopName,
                  child: Icon(
                    i == 0
                        ? Icons.location_on
                        : i == points.length - 1
                            ? Icons.flag
                            : Icons.place,
                    color: i == 0
                        ? Colors.green
                        : i == points.length - 1
                            ? Colors.red
                            : Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
