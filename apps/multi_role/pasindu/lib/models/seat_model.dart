class Seat {
  final int seatId;
  final String seatLabel;
  final int seatRow;
  final int seatCol;
  final String seatType;
  final bool isBooked;

  Seat({
    required this.seatId,
    required this.seatLabel,
    required this.seatRow,
    required this.seatCol,
    required this.seatType,
    required this.isBooked,
  });

  factory Seat.fromJson(Map<String, dynamic> j) {
    return Seat(
      seatId: (j["seat_id"] as num).toInt(),
      seatLabel: (j["seat_label"] ?? "") as String,
      seatRow: (j["seat_row"] as num).toInt(),
      seatCol: (j["seat_col"] as num).toInt(),
      seatType: (j["seat_type"] ?? "normal") as String,
      isBooked: (j["is_booked"] ?? false) as bool,
    );
  }
}
