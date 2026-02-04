import 'json_parse.dart';

class ConductorBooking {
  final int bookingId;
  final int tripId;
  final int userId;

  final int seatId;
  final String seatNumber;

  final int boardingStopId;
  final String boardingStopName;

  final int droppingStopId;
  final String droppingStopName;

  final String passengerName;
  final String passengerPhone;

  final double price;

  final String status; // confirmed
  final String paidVia; // card/cash
  final String paymentStatus; // paid/pending

  final DateTime? paidAt;
  final int? paidBy;

  final DateTime? boardedAt;
  final int? boardedBy;

  final DateTime? qrScannedAt;
  final int? lastScannedBy;
  final String? verificationSource;

  ConductorBooking({
    required this.bookingId,
    required this.tripId,
    required this.userId,
    required this.seatId,
    required this.seatNumber,
    required this.boardingStopId,
    required this.boardingStopName,
    required this.droppingStopId,
    required this.droppingStopName,
    required this.passengerName,
    required this.passengerPhone,
    required this.price,
    required this.status,
    required this.paidVia,
    required this.paymentStatus,
    required this.paidAt,
    required this.paidBy,
    required this.boardedAt,
    required this.boardedBy,
    required this.qrScannedAt,
    required this.lastScannedBy,
    required this.verificationSource,
  });

  factory ConductorBooking.fromJson(Map<String, dynamic> j) {
    DateTime? dt(dynamic s) {
      final str = (s == null) ? null : s.toString();
      if (str == null || str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    return ConductorBooking(
      bookingId: jInt(j["booking_id"]),
      tripId: jInt(j["trip_id"]),
      userId: jInt(j["user_id"]),
      seatId: jInt(j["seat_id"]),
      seatNumber: jStr(j["seat_number"]),
      boardingStopId: jInt(j["boarding_stop_id"]),
      boardingStopName: jStr(j["boarding_stop_name"]),
      droppingStopId: jInt(j["dropping_stop_id"]),
      droppingStopName: jStr(j["dropping_stop_name"]),
      passengerName: jStr(j["passenger_name"]),
      passengerPhone: jStr(j["passenger_phone"]),
      price: jDouble(j["price"]),
      status: jStr(j["status"]),
      paidVia: jStr(j["paid_via"]),
      paymentStatus: jStr(j["payment_status"]),
      paidAt: dt(j["paid_at"]),
      paidBy: (j["paid_by"] == null) ? null : jInt(j["paid_by"]),
      boardedAt: dt(j["boarded_at"]),
      boardedBy: (j["boarded_by"] == null) ? null : jInt(j["boarded_by"]),
      qrScannedAt: dt(j["qr_scanned_at"]),
      lastScannedBy: (j["last_scanned_by"] == null) ? null : jInt(j["last_scanned_by"]),
      verificationSource: j["verification_source"]?.toString(),
    );
  }

  bool get isBoarded => boardedAt != null;
  bool get isPaid => paymentStatus.toLowerCase() == "paid";
  bool get isCashPending => paidVia.toLowerCase() == "cash" && !isPaid;
}
