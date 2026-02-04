import 'package:flutter/material.dart';
import 'services/operator_api.dart';

class OperatorTicketsPage extends StatefulWidget {
  const OperatorTicketsPage({super.key});

  @override
  State<OperatorTicketsPage> createState() => _OperatorTicketsPageState();
}

class _OperatorTicketsPageState extends State<OperatorTicketsPage> {
  final _bookingIdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _bookingIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final bookingText = _bookingIdCtrl.text.trim();

    if (bookingText.isEmpty) {
      setState(() {
        _error = "Booking ID is required.";
        _result = null;
      });
      return;
    }

    final bookingId = bookingText.isEmpty ? null : int.tryParse(bookingText);
    if (bookingText.isNotEmpty && bookingId == null) {
      setState(() {
        _error = "Booking ID must be a number.";
        _result = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await OperatorApi.validateTicket(
        bookingId: bookingId,
      );
      if (!mounted) return;
      setState(() {
        _result = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _result = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Validate Tickets"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Ticket Lookup",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bookingIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Booking ID",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _validate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Validate Ticket"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (result != null)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Ticket Details",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _infoRow("Booking ID", _safeStr(result["bookingId"])),
                      _infoRow("Status", _safeStr(result["bookingStatus"])),
                      _infoRow("Paid Via", _safeStr(result["paidVia"])),
                      _infoRow("Price", _safeStr(result["price"])),
                      _infoRow("Seat", _safeStr(result["seatLabel"])),
                      const Divider(height: 24),
                      const Text(
                        "Passenger",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      _infoRow("Name", _safeStr(result["passenger"]?["name"])),
                      _infoRow("Email", _safeStr(result["passenger"]?["email"])),
                      const Divider(height: 24),
                      const Text(
                        "Trip",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      _infoRow("Route", _safeStr(result["trip"]?["routeName"])),
                      _infoRow("From", _safeStr(result["trip"]?["from"])),
                      _infoRow("To", _safeStr(result["trip"]?["to"])),
                      _infoRow("Trip Date", _safeStr(result["trip"]?["tripDate"])),
                      _infoRow("Departure", _safeStr(result["trip"]?["departureTime"])),
                      _infoRow("Arrival", _safeStr(result["trip"]?["arrivalTime"])),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
