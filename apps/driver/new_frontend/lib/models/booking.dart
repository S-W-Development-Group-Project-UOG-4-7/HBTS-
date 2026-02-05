class Booking {
  final int bookingId;
  final int userId;
  final int tripId;
  final int seatId;
  final String seatNumber;
  final String passengerName;
  final String passengerPhone;
  final String boardingStop;
  final String droppingStop;
  final double price;
  final String status;

  Booking({
    required this.bookingId,
    required this.userId,
    required this.tripId,
    required this.seatId,
    required this.seatNumber,
    required this.passengerName,
    required this.passengerPhone,
    required this.boardingStop,
    required this.droppingStop,
    required this.price,
    required this.status,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      bookingId: json['booking_id'],
      userId: json['user_id'],
      tripId: json['trip_id'],
      seatId: json['seat_id'],
      seatNumber: json['seat_number'] ?? 'N/A',
      passengerName: json['passenger_name'] ?? 'Unknown',
      passengerPhone: json['passenger_phone'] ?? '',
      boardingStop: json['boarding_stop'] ?? '',
      droppingStop: json['dropping_stop'] ?? '',
      price: json['price'] is String
          ? double.parse(json['price'])
          : (json['price'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
    );
  }
}
