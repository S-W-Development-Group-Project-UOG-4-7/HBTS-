# Highway Bus Transportation System - Driver App

A modern, user-friendly driver application for managing bus trips, viewing routes, tracking passengers, and sending telemetry data.

## Features

### Driver Functionality
- **Dashboard**: View assigned trips with statistics (scheduled, running, completed)
- **Trip Management**: Start and end trips with real-time status updates
- **Route View**: See all stops along the route with detailed information
- **Booked Seats**: View passenger bookings with seat numbers and contact details
- **Telemetry**: Send real-time GPS location data during trips

## Tech Stack

### Frontend
- **Flutter/Dart**: Cross-platform mobile framework
- **Provider**: State management
- **HTTP**: API communication
- **Geolocator**: GPS location services

### Backend
- **Node.js**: Server runtime
- **Express**: Web framework
- **PostgreSQL (Neon)**: Database
- **CORS**: Cross-origin resource sharing

## Project Structure

```
New/
├── Backend/                 # Node.js API Server
│   ├── config/
│   │   └── db.js           # Database connection
│   ├── controllers/
│   │   └── driverController.js
│   ├── routes/
│   │   └── driverRoutes.js
│   ├── server.js           # Main server file
│   ├── package.json
│   └── .env                # Environment variables
│
└── Frontend/               # Flutter App
    ├── lib/
    │   ├── main.dart       # App entry point
    │   ├── screens/        # UI screens
    │   │   ├── driver_dashboard.dart
    │   │   ├── driver_trips.dart
    │   │   ├── trip_detail.dart
    │   │   ├── route_view.dart
    │   │   ├── booked_seats.dart
    │   │   └── telemetry_screen.dart
    │   ├── models/         # Data models
    │   │   ├── trip.dart
    │   │   ├── booking.dart
    │   │   └── route_stop.dart
    │   └── services/       # API services
    │       └── api_service.dart
    └── pubspec.yaml        # Flutter dependencies
```

## Setup Instructions

### Prerequisites
- Node.js (v16 or higher)
- Flutter SDK (v3.0 or higher)
- Android Studio (for Android Emulator)
- Git

### Backend Setup

#### On Mac:
```bash
cd Backend
npm install
node server.js
```

#### On Windows:
```bash
cd Backend
npm install
node server.js
```

The server will start on `http://localhost:3000`

**Test the backend:**
```bash
curl http://localhost:3000/health
```

### Frontend Setup

#### On Mac:
```bash
cd Frontend
flutter pub get
flutter run
```

#### On Windows:
```bash
cd Frontend
flutter pub get
flutter run
```

### Running on Android Emulator

1. **Start Android Emulator:**
   - Open Android Studio
   - Go to Tools > Device Manager
   - Start an Android Virtual Device (AVD)

2. **Update API URL (if needed):**
   - Open `Frontend/lib/services/api_service.dart`
   - The URL is set to `http://10.0.2.2:3000/api` (works for Android Emulator)
   - For real device, change to your computer's IP address

3. **Run the app:**
   ```bash
   cd Frontend
   flutter run
   ```

### Environment Configuration

**Backend (.env):**
```env
PORT=3000
DATABASE_URL=postgresql://neondb_owner:npg_L8sOGVMiblF6@ep-purple-paper-a1et8t1z-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

**Frontend API URL:**
- Android Emulator: `http://10.0.2.2:3000/api`
- Real Device: `http://YOUR_COMPUTER_IP:3000/api`
- iOS Simulator: `http://localhost:3000/api`

## API Endpoints

### Driver Endpoints
- `GET /api/driver/:driverId/trips` - Get driver's assigned trips
- `PUT /api/driver/trip/:tripId/start` - Start a trip
- `PUT /api/driver/trip/:tripId/end` - End a trip
- `GET /api/driver/trip/:tripId/route` - Get route stops
- `GET /api/driver/trip/:tripId/bookings` - Get booked seats
- `POST /api/driver/trip/:tripId/telemetry` - Send GPS data

### Health Check
- `GET /health` - Check API status

## Database Schema

### Key Tables
- **users**: User accounts with role-based access (role_id: 4 = driver)
- **drivers**: Driver-specific information
- **trips**: Trip schedules and status
- **routes**: Route information
- **bookings**: Passenger seat bookings
- **telemetry**: GPS tracking data
- **stops**: Bus stop locations

## Default Configuration

**Default Driver ID**: 6 (Demo Driver)
- Change in `Frontend/lib/screens/driver_dashboard.dart` line 15

**Backend Port**: 3000
- Change in `Backend/.env`

**Database**: Neon PostgreSQL (already configured)

## Features Breakdown

### 1. Dashboard Screen
- Welcome card with driver info
- Statistics cards (scheduled, running, completed, total trips)
- Quick action buttons
- Pull-to-refresh

### 2. Trips Screen
- List of all assigned trips
- Filter by status (all, scheduled, running, completed)
- Trip cards with route and timing info
- Tap to view details

### 3. Trip Detail Screen
- Complete trip information
- Start/End trip buttons
- View route stops
- View booked seats
- Send telemetry (when trip is running)

### 4. Route View Screen
- Timeline of all stops
- Stop sequence numbers
- Arrival/departure times
- GPS coordinates

### 5. Booked Seats Screen
- List of all passengers
- Seat numbers
- Contact information
- Boarding/dropping locations
- Booking status

### 6. Telemetry Screen
- Real-time GPS location
- Speed and heading
- Send location to backend
- Location accuracy info

## Color Theme

- **Primary**: Blue (#2196F3)
- **Success**: Green (#4CAF50)
- **Warning**: Orange (#FF9800)
- **Error**: Red (#F44336)
- **Background**: Light Grey (#F5F5F5)

## Troubleshooting

### Backend Issues

**Port already in use:**
```bash
# On Mac/Linux:
lsof -ti:3000 | xargs kill -9

# On Windows:
netstat -ano | findstr :3000
taskkill /PID <PID> /F
```

**Database connection error:**
- Check internet connection
- Verify DATABASE_URL in .env file

### Flutter Issues

**Dependencies not installing:**
```bash
flutter clean
flutter pub get
```

**App not connecting to backend:**
- Check if backend server is running
- Verify API URL in `api_service.dart`
- For Android Emulator, use `10.0.2.2` instead of `localhost`

**Location permission denied:**
- On Android, location permissions are requested at runtime
- Grant permissions when prompted

## Transferring to Windows PC

1. **Copy entire project folder** to Windows PC

2. **Install prerequisites on Windows:**
   - Node.js from https://nodejs.org
   - Flutter from https://flutter.dev
   - Android Studio from https://developer.android.com

3. **Setup backend:**
   ```bash
   cd Backend
   npm install
   node server.js
   ```

4. **Setup frontend:**
   ```bash
   cd Frontend
   flutter pub get
   flutter run
   ```

5. **No code changes needed!** Everything will work the same.

## For Tomorrow's Presentation

### Demo Flow:
1. Show **Dashboard** with trip statistics
2. Navigate to **My Trips** and filter by status
3. Select a trip and show **Trip Details**
4. Demonstrate **Start Trip** functionality
5. Show **Route Stops** with timeline
6. Show **Booked Seats** with passenger info
7. Demonstrate **Telemetry** with GPS location
8. **End Trip** to complete the flow

### Key Points to Highlight:
- User-friendly, modern UI design
- Real-time data from PostgreSQL database
- Complete trip management workflow
- GPS tracking capability
- Comprehensive passenger information

## Notes

- Current driver ID is hardcoded as **6** (Demo Driver)
- Database has sample data for testing
- All features are fully functional
- Backend connects to Neon PostgreSQL cloud database
- App works offline for UI, but requires internet for API calls

## Support

For issues or questions:
- Check backend logs in terminal
- Use Chrome DevTools for Flutter debugging
- Test API endpoints using curl or Postman

---

**Built for Highway Bus Transportation System**
**Driver Module - Interim Presentation**
