import 'package:flutter/material.dart';
import '../api/seat_api.dart';
import '../models/seat_model.dart';
import '../models/trip_model.dart';

class EditSeatArgs {
  final Trip trip;
  final int currentSeatId;
  final String currentSeatLabel;

  // ✅ Defaults so old calls won't break
  final bool canChangeSeat;
  final String? lockReason;

  const EditSeatArgs({
    required this.trip,
    required this.currentSeatId,
    required this.currentSeatLabel,
    this.canChangeSeat = true,
    this.lockReason,
  });
}

class EditSeatPage extends StatefulWidget {
  final EditSeatArgs args;
  const EditSeatPage({super.key, required this.args});

  @override
  State<EditSeatPage> createState() => _EditSeatPageState();
}

class _EditSeatPageState extends State<EditSeatPage> {
  bool _loading = true;
  List<Seat> _seats = [];
  int? _selectedSeatId;

  @override
  void initState() {
    super.initState();
    _selectedSeatId = widget.args.currentSeatId;
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    setState(() => _loading = true);
    try {
      final data = await SeatApi.getTripSeats(widget.args.trip.id);

      // allow selecting the current seat even if API marks it booked
      final updated = data.map((s) {
        if (s.seatId == widget.args.currentSeatId) {
          return Seat(
            seatId: s.seatId,
            seatLabel: s.seatLabel,
            seatRow: s.seatRow,
            seatCol: s.seatCol,
            seatType: s.seatType,
            isBooked: false,
          );
        }
        return s;
      }).toList();

      setState(() => _seats = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Seat load failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(Seat seat) {
    if (!widget.args.canChangeSeat) return; // ✅ block when locked
    if (seat.isBooked) return;
    setState(() => _selectedSeatId = seat.seatId);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.args.trip;
    final locked = !widget.args.canChangeSeat;
    final lockText = widget.args.lockReason ?? "Seat change is not available for this booking.";

    final maxRow = _seats.isEmpty ? 0 : _seats.map((s) => s.seatRow).reduce((a, b) => a > b ? a : b);
    final maxCol = _seats.isEmpty ? 0 : _seats.map((s) => s.seatCol).reduce((a, b) => a > b ? a : b);

    final seatByPos = <String, Seat>{};
    for (final s in _seats) {
      seatByPos["${s.seatRow}:${s.seatCol}"] = s;
    }

    final rows = maxRow;
    final cols = maxCol == 0 ? 4 : maxCol;
    final totalCells = rows * cols;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Seat"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${t.fromLocation} → ${t.toLocation}",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 6),
                Text("Current seat: ${widget.args.currentSeatLabel}",
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                if (locked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lockText,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    _Legend(color: Colors.grey.shade300, label: "Available"),
                    const SizedBox(width: 10),
                    _Legend(color: Colors.blue.shade700, label: "Selected"),
                    const SizedBox(width: 10),
                    _Legend(color: Colors.red.shade300, label: "Booked"),
                  ],
                ),
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
                            OutlinedButton(onPressed: _loadSeats, child: const Text("Retry")),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: totalCells,
                          itemBuilder: (context, index) {
                            // ✅ 1-based mapping
                            final r = (index ~/ cols) + 1;
                            final c = (index % cols) + 1;

                            final seat = seatByPos["$r:$c"];
                            if (seat == null || seat.seatType == "aisle") return const SizedBox.shrink();

                            final booked = seat.isBooked;
                            final selected = _selectedSeatId == seat.seatId;

                            Color bg;
                            if (booked) bg = Colors.red.shade300;
                            else if (selected) bg = Colors.blue.shade700;
                            else bg = Colors.grey.shade200;

                            return InkWell(
                              onTap: () => _select(seat),
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
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (locked || _selectedSeatId == null)
                      ? null
                      : () => Navigator.pop(context, _selectedSeatId),
                  child: const Text("Save Seat",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
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
