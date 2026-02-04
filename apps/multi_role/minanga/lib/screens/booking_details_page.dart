import 'package:flutter/material.dart';
import '../api/booking_api.dart';
import '../api/seat_api.dart';
import '../models/my_booking_item.dart';
import '../models/seat_model.dart';
import '../models/trip_model.dart';
import 'edit_seat_page.dart';

class BookingDetailsPage extends StatefulWidget {
  final MyBookingItem item;
  const BookingDetailsPage({super.key, required this.item});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  bool _loadingSeats = true;
  List<Seat> _seats = [];

  late int _seatId;
  late String _seatLabel;

  @override
  void initState() {
    super.initState();
    _seatId = widget.item.seatId;
    _seatLabel = widget.item.seatLabel;
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    setState(() => _loadingSeats = true);
    try {
      final data = await SeatApi.getTripSeats(widget.item.tripId);
      if (!mounted) return;
      setState(() => _seats = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Seat load failed: $e")));
    } finally {
      if (mounted) {
        setState(() => _loadingSeats = false);
      }
    }
  }

  Trip _tripFromItem(MyBookingItem b) {
    return Trip(
      id: b.tripId,
      routeName: b.routeName,
      fromLocation: b.fromLocation,
      toLocation: b.toLocation,
      tripDate: b.tripDate,
      departureTime: b.departureTime,
      arrivalTime: b.arrivalTime,
      status: b.tripStatus,
      capacity: 0,
      serviceType: "",
    );
  }

  String? get _lockReason {
    final trip = widget.item.tripStatus.toLowerCase();
    final st = widget.item.status.toLowerCase();

    if (trip != "scheduled") return "Seat changes are available only for scheduled trips.";
    if (st == "cancelled") return "This booking is cancelled.";
    return null; // allowed (backend still enforces time windows)
  }

  bool get _canEdit => _lockReason == null;

  @override
  Widget build(BuildContext context) {
    final b = widget.item;
    final trip = _tripFromItem(b);

    return Scaffold(
      appBar: AppBar(title: const Text("Booking Details")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(b.routeText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text("Seat: $_seatLabel"),
          const SizedBox(height: 6),
          Text("Departure: ${b.departureTime}"),
          const SizedBox(height: 16),

          const Text("Seat Map", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _loadingSeats
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ))
              : SeatMapFromSeats(seats: _seats, mySeatId: _seatId),

          const SizedBox(height: 16),

          if (_canEdit) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.event_seat),
                label: const Text("Change Seat"),
                onPressed: () async {
                  final newSeatId = await Navigator.push<int>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditSeatPage(
                        args: EditSeatArgs(
                          trip: trip,
                          currentSeatId: _seatId,
                          currentSeatLabel: _seatLabel,
                          canChangeSeat: _canEdit,
                          lockReason: _lockReason,
                        ),
                      ),
                    ),
                  );

                  if (newSeatId == null || newSeatId == _seatId) return;

                  try {
                    await BookingApi.changeSeat(bookingId: b.bookingId, seatId: newSeatId);
                    if (!context.mounted) return;

                    final newSeat = _seats.firstWhere((s) => s.seatId == newSeatId);
                    setState(() {
                      _seatId = newSeatId;
                      _seatLabel = newSeat.seatLabel;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Seat updated")),
                    );
                    await _loadSeats();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Seat update failed: $e")),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text("Cancel Booking"),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Cancel booking?"),
                      content: const Text("This cannot be undone."),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
                      ],
                    ),
                  );

                  if (ok != true) return;

                  try {
                    await BookingApi.cancelBooking(bookingId: b.bookingId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Booking cancelled")),
                    );
                    Navigator.pop(context);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Cancel failed: $e")),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SeatMapFromSeats extends StatelessWidget {
  final List<Seat> seats;
  final int mySeatId;

  const SeatMapFromSeats({super.key, required this.seats, required this.mySeatId});

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return const Text("No seats.");
    }

    final maxRow = seats.map((s) => s.seatRow).reduce((a, b) => a > b ? a : b);
    final maxCol = seats.map((s) => s.seatCol).reduce((a, b) => a > b ? a : b);

    final seatByPos = <String, Seat>{};
    for (final s in seats) {
      seatByPos["${s.seatRow}:${s.seatCol}"] = s;
    }

    final rows = maxRow;
    final cols = maxCol == 0 ? 4 : maxCol;
    final totalCells = rows * cols;

    return GridView.builder(
      itemCount: totalCells,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (_, index) {
        // ✅ 1-based mapping
        final r = (index ~/ cols) + 1;
        final c = (index % cols) + 1;

        final seat = seatByPos["$r:$c"];
        if (seat == null || seat.seatType == "aisle") {
          return const SizedBox.shrink();
        }

        final isMine = seat.seatId == mySeatId;
        final booked = seat.isBooked;

        Color bg;
        if (isMine) {
          bg = Colors.blue.shade700;
        } else if (booked) {
          bg = Colors.red.shade300;
        } else {
          bg = Colors.grey.shade200;
        }

        return Container(
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
                color: (isMine || booked) ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }
}

