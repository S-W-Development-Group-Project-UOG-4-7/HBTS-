import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../api/seat_api.dart';
import '../models/seat_model.dart';
import '../models/trip_model.dart';
import 'confirm_booking_page.dart';

class SeatSelectArgs {
  final Trip trip;
  final int passengers;
  SeatSelectArgs({required this.trip, required this.passengers});
}

class SeatSelectionPage extends StatefulWidget {
  final SeatSelectArgs args;
  const SeatSelectionPage({super.key, required this.args});

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> {
  bool _loading = true;
  List<Seat> _seats = [];

  final Set<int> _selectedSeatIds = {};

  int get _maxSelect => widget.args.passengers;

  @override
  void initState() {
    super.initState();
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    setState(() => _loading = true);
    try {
      final data = await SeatApi.getTripSeats(widget.args.trip.id);
      setState(() {
        _seats = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Seat load failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Seat seat) {
    if (seat.isBooked) return;

    setState(() {
      if (_selectedSeatIds.contains(seat.seatId)) {
        _selectedSeatIds.remove(seat.seatId);
      } else {
        if (_selectedSeatIds.length >= _maxSelect) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("You can select only $_maxSelect seat(s).")),
          );
          return;
        }
        _selectedSeatIds.add(seat.seatId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.args.trip;

    // Build a grid size from max row/col
    final maxRow = _seats.isEmpty ? 0 : _seats.map((s) => s.seatRow).reduce((a, b) => a > b ? a : b);
    final maxCol = _seats.isEmpty ? 0 : _seats.map((s) => s.seatCol).reduce((a, b) => a > b ? a : b);

    final totalSeats = _selectedSeatIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Seats"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Legend(color: Colors.grey.shade300, label: "Available"),
                const SizedBox(width: 10),
                _Legend(color: Colors.blue.shade700, label: "Selected"),
                const SizedBox(width: 10),
                _Legend(color: Colors.red.shade300, label: "Booked"),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _seats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("No seats found for this trip."),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _loadSeats,
                              child: const Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: maxCol == 0 ? 4 : maxCol,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _seats.length,
                          itemBuilder: (context, i) {
                            final seat = _seats[i];
                            final booked = seat.isBooked;
                            final selected = _selectedSeatIds.contains(seat.seatId);

                            Color bg;
                            if (booked) {
                              bg = Colors.red.shade300;
                            } else if (selected) {
                              bg = Colors.blue.shade700;
                            } else {
                              bg = Colors.grey.shade200;
                            }

                            return InkWell(
                              onTap: () => _toggle(seat),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Center(
                                  child: Text(
                                    seat.seatLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: booked || selected ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Selected: $totalSeats/$_maxSelect",
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _selectedSeatIds.isEmpty
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.confirmBooking,
                                arguments: ConfirmBookingArgs(
                                  trip: t,
                                  seatIds: _selectedSeatIds.toList()..sort(),
                                ),
                              );
                            },
                      child: const Text(
                        "Continue",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}