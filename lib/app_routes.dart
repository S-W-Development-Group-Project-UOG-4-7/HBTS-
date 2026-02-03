import 'package:flutter/material.dart';

import 'admin/dashboard.dart';
import 'conductor/conductor_active_trip_page.dart';
import 'conductor/conductor_booking_details_page.dart';
import 'conductor/conductor_bookings_page.dart';
import 'conductor/conductor_shell.dart';
import 'conductor/scan_qr_page.dart';
import 'operator/operator_start_page.dart';
import 'screens/booking_success_page.dart';
import 'screens/confirm_booking_page.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/my_bookings_page.dart';
import 'screens/notifications_page.dart';
import 'screens/profile_page.dart';
import 'screens/schedule_page.dart';
import 'screens/seat_selection_page.dart';
import 'screens/track_bus_page.dart';
import 'screens/track_my_booking_page.dart';
import 'screens/trip_details_page.dart';

class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const profile = '/profile';
  static const operator = '/operator';
  static const schedule = '/schedule';
  static const myBookings = '/my-bookings';
  static const trackMyBooking = '/track-my-booking';
  static const trackBus = '/track-bus';
  static const notifications = '/notifications';
  static const conductorHome = '/conductor';
  static const conductorScan = '/conductor/scan';
  static const conductorActiveTrip = '/conductor/active-trip';
  static const conductorBookings = '/conductor/bookings';
  static const conductorBookingDetails = '/conductor/booking-details';
  static const upcomingToday = '/upcoming-today';

  static const tripDetails = '/trip-details';
  static const seatSelect = '/seat-select';
  static const confirmBooking = '/confirm-booking';
  static const bookingSuccess = '/booking-success';

  static const adminHome = '/admin/dashboard';

  static Route<dynamic> onGenerate(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case adminHome:
        return MaterialPageRoute(builder: (_) => const AdminDashboard());

      case conductorHome:
        return MaterialPageRoute(builder: (_) => const ConductorShell());

      case conductorScan:
        return MaterialPageRoute(builder: (_) => const ConductorScanPage());

      case conductorActiveTrip:
        return MaterialPageRoute(builder: (_) => const ConductorActiveTripPage());

      case conductorBookings:
        final args = settings.arguments;
        if (args is Map && args["tripId"] is int) {
          return MaterialPageRoute(
            builder: (_) => ConductorBookingsPage(tripId: args["tripId"] as int),
          );
        }
        return _badRoute("ConductorBookings args missing");

      case conductorBookingDetails:
        final args = settings.arguments;
        if (args is Map && args["booking"] != null) {
          return MaterialPageRoute(
            builder: (_) => ConductorBookingDetailsPage(booking: args["booking"]),
          );
        }
        return _badRoute("ConductorBookingDetails args missing");

      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());

      case operator:
        return MaterialPageRoute(builder: (_) => const OperatorStartPage());

      case profile:
        final args = settings.arguments;
        if (args is ProfileArgs) {
          return MaterialPageRoute(builder: (_) => ProfilePage(args: args));
        }
        return _badRoute("Profile args missing");

      case schedule:
        return MaterialPageRoute(builder: (_) => const SchedulePage());

      case myBookings:
        return MaterialPageRoute(builder: (_) => const PassengerBookingsPage());

      case upcomingToday:
        return MaterialPageRoute(builder: (_) => const PassengerBookingsPage());

      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());

      case trackMyBooking:
        return MaterialPageRoute(builder: (_) => const TrackMyBookingPage());

      case trackBus:
        return MaterialPageRoute(builder: (_) => const TrackBusPage());

      // New flow routes (must be before default)
      case tripDetails:
        final args = settings.arguments;
        if (args is TripDetailsArgs) {
          return MaterialPageRoute(builder: (_) => TripDetailsPage(args: args));
        }
        return _badRoute("TripDetails args missing");

      case seatSelect:
        final args = settings.arguments;
        if (args is SeatSelectArgs) {
          return MaterialPageRoute(builder: (_) => SeatSelectionPage(args: args));
        }
        return _badRoute("SeatSelect args missing");

      case confirmBooking:
        final args = settings.arguments;
        if (args is ConfirmBookingArgs) {
          return MaterialPageRoute(builder: (_) => ConfirmBookingPage(args: args));
        }
        return _badRoute("ConfirmBooking args missing");

      case bookingSuccess:
        final args = settings.arguments;
        if (args is BookingSuccessArgs) {
          return MaterialPageRoute(builder: (_) => BookingSuccessPage(args: args));
        }
        return _badRoute("BookingSuccess args missing");

      // Default must be last
      default:
        return _badRoute("Route not found: ${settings.name}");
    }
  }

  static Route<dynamic> _badRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text("Navigation error")),
        body: Center(child: Text(message)),
      ),
    );
  }
}

// Profile arguments
class ProfileArgs {
  final String name;
  final String email;
  final String id;
  final String? phone;
  final String? photoUrl;

  ProfileArgs({
    required this.name,
    required this.email,
    required this.id,
    this.phone,
    this.photoUrl,
  });
}
