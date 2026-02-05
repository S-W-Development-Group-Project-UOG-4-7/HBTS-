# Quick Start Guide - Driver App

## For Immediate Testing (Mac)

### 1. Start Backend (Terminal 1)
```bash
cd /Users/gavinkahanda/Desktop/New/Backend
node server.js
```

You should see:
```
🚀 HBTS Driver API running on port 3000
📍 Health check: http://localhost:3000/health
✅ Connected to Neon PostgreSQL database
```

### 2. Run Flutter App (Terminal 2)
```bash
cd /Users/gavinkahanda/Desktop/New/Frontend
flutter pub get
flutter run
```

Select your Android emulator when prompted.

## For Windows PC

### 1. Start Backend (Command Prompt)
```bash
cd Backend
node server.js
```

### 2. Run Flutter App (New Command Prompt)
```bash
cd Frontend
flutter pub get
flutter run
```

## Testing the API

```bash
# Health check
curl http://localhost:3000/health

# Get driver trips (Driver ID: 6)
curl http://localhost:3000/api/driver/6/trips

# Get bookings for trip 9
curl http://localhost:3000/api/driver/trip/9/bookings

# Get route stops for trip 9
curl http://localhost:3000/api/driver/trip/9/route
```

## Demo Data

**Driver ID**: 6 (Demo Driver - driver.demo@hbts.lk)

**Sample Trips**:
- Trip #9: Maharagama → Horana (RUNNING)
- Trip #8: Maharagama → Horana (SCHEDULED)
- Trip #3: Colombo → Kandy (SCHEDULED)

## Common Issues

**"Port 3000 already in use"**
```bash
lsof -ti:3000 | xargs kill -9
```

**"No devices connected"**
- Open Android Studio
- Tools > Device Manager > Start Emulator

**"App can't connect to backend"**
- Make sure backend is running
- Check if using correct IP (10.0.2.2 for emulator)

## Presentation Demo Path

1. **Dashboard** → Shows 3 trips, statistics
2. **View All Trips** → Shows trip list with filters
3. **Select Trip #9** (Running) → Trip details
4. **View Route Stops** → Shows Maharagama-Horana route
5. **View Booked Seats** → Shows passenger list
6. **Send Telemetry** → Shows GPS data
7. **End Trip** → Completes the trip
8. **Back to Dashboard** → Shows updated statistics

## File Locations

**Backend**: `/Users/gavinkahanda/Desktop/New/Backend`
**Frontend**: `/Users/gavinkahanda/Desktop/New/Frontend`
**Database**: Neon PostgreSQL (cloud-hosted)

---

**Ready to present tomorrow!** 🚀
