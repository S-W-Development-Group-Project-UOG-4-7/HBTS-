# Windows PC Setup Guide

## ⚡ Quick Setup on Windows

### 1. Prerequisites - Install These First

Download and install:
- **Node.js**: https://nodejs.org (LTS version)
- **Flutter**: https://docs.flutter.dev/get-started/install/windows
- **Android Studio**: https://developer.android.com/studio

### 2. Copy Project to Windows
Transfer the entire `New` folder to your Windows PC

### 3. Start Backend

Open Command Prompt:
```bash
cd New\Backend
npm install
node server.js
```

You should see:
```
🚀 HBTS Driver API running on port 3000
✅ Connected to Neon PostgreSQL database
```

**Keep this window open!**

### 4. Run Flutter App

Open **NEW** Command Prompt window:
```bash
cd New\Frontend
flutter doctor
flutter pub get
flutter run
```

### 5. Select Android Emulator

When prompted, choose your Android emulator.

---

## ✅ Verification Checklist

Before running, verify these files exist:

### Backend Files:
- ✅ `Backend/server.js`
- ✅ `Backend/package.json`
- ✅ `Backend/.env`
- ✅ `Backend/config/db.js`
- ✅ `Backend/controllers/driverController.js`
- ✅ `Backend/routes/driverRoutes.js`

### Frontend Files:
- ✅ `Frontend/pubspec.yaml`
- ✅ `Frontend/lib/main.dart`
- ✅ `Frontend/lib/screens/` (7 screen files)
- ✅ `Frontend/lib/models/` (3 model files)
- ✅ `Frontend/lib/services/api_service.dart`
- ✅ `Frontend/android/` (Android config folder)

---

## 🐛 Troubleshooting Windows

### "Port 3000 already in use"
```bash
netstat -ano | findstr :3000
taskkill /PID <PID_NUMBER> /F
```

### "Flutter command not found"
Add Flutter to PATH:
1. Search "Environment Variables" in Windows
2. Edit System PATH
3. Add: `C:\src\flutter\bin` (your Flutter install location)
4. Restart Command Prompt

### "Android license not accepted"
```bash
flutter doctor --android-licenses
```

### "Gradle build failed"
```bash
cd Frontend\android
gradlew clean
cd ..\..
flutter clean
flutter pub get
```

---

## 📱 Android Emulator Setup

1. Open Android Studio
2. Tools → Device Manager
3. Create Device → Pixel 5
4. Select System Image → R (API 30)
5. Finish → Start Emulator

---

## 🔧 Configuration

### Change Driver ID
Edit `Frontend\lib\screens\driver_dashboard.dart`
- Line 15: Change `final int driverId = 6;` to your driver ID

### Change Backend URL (if needed)
Edit `Frontend\lib\services\api_service.dart`
- Line 12: Change URL if backend is on different machine

For different PC:
```dart
static const String baseUrl = 'http://YOUR_PC_IP:3000/api';
```

For emulator (default):
```dart
static const String baseUrl = 'http://10.0.2.2:3000/api';
```

---

## ✨ Features Working

- ✅ Dashboard with statistics
- ✅ Trip list with filters
- ✅ Start/End trips
- ✅ View route stops
- ✅ View booked seats
- ✅ Send GPS telemetry
- ✅ Real-time database updates

---

## 📊 Test Data Available

**Driver**: ID 6 (Demo Driver)

**Trips**:
- Trip #9: Maharagama → Horana (RUNNING)
- Trip #8: Maharagama → Horana (SCHEDULED)
- Trip #3: Colombo → Kandy (SCHEDULED)

---

## 🎯 For Demo Tomorrow

### Run This Sequence:
1. Start backend → Wait for "Connected" message
2. Start emulator → Wait fully loaded
3. Run Flutter app → Select emulator
4. App opens to Dashboard automatically

### Demo Flow:
Dashboard → Trips → Select Running Trip → View Details → Route → Bookings → Telemetry → End Trip

---

## 💡 Quick Tips

- Backend MUST be running before starting app
- Use `flutter clean` if strange errors occur
- Android Emulator needs 8GB RAM recommended
- Check Windows Firewall if connection fails
- Use `flutter run -v` for detailed logs

---

**Everything is ready! Just follow these steps on Windows.** 🚀
