# GoFleet Driver App - Location Tracking

Detailed documentation for the location tracking system in the GoFleet Driver app.

---

## Overview

The location tracking system enables real-time driver position updates while on shift. It includes:
- Automatic GPS tracking when on shift
- Rate limiting to prevent API overload
- Offline queueing for unreliable connections
- Battery-efficient position streaming

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                     Location Service                           │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     │
│   │  Geolocator │ ──▶ │Rate Limiter │ ──▶ │   Sender    │     │
│   │   Stream    │     │ (2/10 sec)  │     │             │     │
│   └─────────────┘     └─────────────┘     └──────┬──────┘     │
│                                                  │             │
│                                                  ▼             │
│                             ┌─────────────────────────────┐   │
│                             │      Online?                │   │
│                             │         │                   │   │
│                             │    ┌────┴────┐              │   │
│                             │  Yes        No              │   │
│                             │    │         │              │   │
│                             │    ▼         ▼              │   │
│                             │  ┌───────┐ ┌───────────┐    │   │
│                             │  │  API  │ │   Queue   │    │   │
│                             │  │ Upload│ │ (max 100) │    │   │
│                             │  └───────┘ └───────────┘    │   │
│                             └─────────────────────────────┘   │
│                                                                │
│   ┌─────────────────────────────────────────────────────┐     │
│   │               Connectivity Monitor                   │     │
│   │    Wifi/Mobile ──▶ Upload Queue when back online     │     │
│   └─────────────────────────────────────────────────────┘     │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## Components

### LocationService

Main service class for tracking and uploading driver location.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isTracking` | bool | Whether tracking is active |
| `isOnline` | bool | Network connectivity status |
| `lastPosition` | Position? | Most recent GPS position |
| `lastUploadTime` | DateTime? | Time of last successful API upload |
| `queuedUpdatesCount` | int | Number of pending offline updates |

#### Methods

| Method | Description |
|--------|-------------|
| `checkPermission()` | Check if location permission granted |
| `requestPermission()` | Request location permission |
| `isLocationServiceEnabled()` | Check if GPS is enabled |
| `getCurrentPosition()` | Get current GPS position |
| `startTracking()` | Begin continuous tracking |
| `stopTracking()` | Stop tracking |

---

### LocationUpdate Model

```dart
class LocationUpdate {
  final double lat;       // Latitude
  final double lng;       // Longitude
  final double? speed;    // Speed in m/s
  final double? heading;  // Heading in degrees
  final double? accuracy; // Accuracy in meters
  final DateTime capturedAt; // Timestamp
}
```

---

## Rate Limiting

To prevent API overload, updates are rate limited to **2 updates per 10 seconds**.

### Implementation

```dart
// Configuration
static const int locationRateLimitPerInterval = 2;
static const Duration locationRateLimitInterval = Duration(seconds: 10);

// Rate check logic
bool _shouldSendUpdate() {
  final now = DateTime.now();
  
  // Reset counter if interval passed
  if (_intervalStartTime == null ||
      now.difference(_intervalStartTime!).inSeconds >= 10) {
    _intervalStartTime = now;
    _updateCountInInterval = 0;
  }

  // Check limit
  if (_updateCountInInterval < 2) {
    _updateCountInInterval++;
    return true;
  }

  return false; // Rate limited
}
```

### Behavior

| Scenario | Action |
|----------|--------|
| First update in interval | Send immediately |
| Second update in interval | Send immediately |
| Third+ update in interval | Skip (rate limited) |
| After 10 seconds | Reset counter, send next update |

---

## Offline Queue

When network is unavailable, location updates are queued for later upload.

### Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| Max queue size | 100 | Maximum pending updates |
| Upload delay | 100ms | Delay between queued uploads |

### Queue Behavior

1. **When offline**: Updates added to queue (FIFO)
2. **If queue full**: Oldest update removed
3. **When online**: Queue processed in order
4. **Upload error**: Processing stops, retries next interval

### Implementation

```dart
// Queue location when offline
void _queueLocationUpdate(LocationUpdate update) {
  if (_offlineQueue.length >= _maxQueueSize) {
    _offlineQueue.removeFirst(); // Remove oldest
  }
  _offlineQueue.add(update);
}

// Upload queue when back online
Future<void> _uploadQueuedLocations() async {
  while (_offlineQueue.isNotEmpty && _isOnline) {
    final update = _offlineQueue.first;
    
    try {
      await _apiClient.updateLocation(...);
      _offlineQueue.removeFirst();
      await Future.delayed(Duration(milliseconds: 100));
    } catch (e) {
      break; // Stop on error, retry later
    }
  }
}
```

---

## Position Stream

Location updates are received via Geolocator stream with these settings:

```dart
const locationSettings = LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 10, // Minimum 10 meters movement
);
```

### Settings Explanation

| Setting | Value | Description |
|---------|-------|-------------|
| accuracy | high | Use GPS for best accuracy |
| distanceFilter | 10m | Only trigger update after 10m movement |

### Battery Optimization

The `distanceFilter` of 10 meters prevents constant updates when the driver is stationary, saving battery.

---

## API Endpoint

```http
POST /driver/location
Authorization: Bearer <token>
Content-Type: application/json

{
  "lat": 40.7128,
  "lng": -74.0060,
  "speed": 12.5,
  "heading": 180.0,
  "accuracy": 10.0,
  "captured_at": "2024-01-15T10:30:00.000Z"
}
```

### Response

```http
200 OK
{
  "status": "ok"
}
```

### Error Codes

| Code | Description |
|------|-------------|
| 401 | Unauthorized (invalid token) |
| 403 | DRIVER_NOT_ON_DUTY (shift not started) |
| 429 | RATE_LIMIT_EXCEEDED (server-side limit) |

---

## Usage

### Starting Tracking (when shift starts)

```dart
// In DriverNotifier.startShift()
Future<void> startShift() async {
  await _apiClient.startShift();
  
  // Start location tracking
  ref.read(locationProvider.notifier).startTracking();
}
```

### Stopping Tracking (when shift ends)

```dart
// In DriverNotifier.endShift()
Future<void> endShift() async {
  await _apiClient.endShift();
  
  // Stop location tracking
  ref.read(locationProvider.notifier).stopTracking();
}
```

### Checking Permission

```dart
// In Settings or Home screen
final hasPermission = ref.watch(hasLocationPermissionProvider);

if (!hasPermission) {
  // Show permission request UI
  await ref.read(locationProvider.notifier).requestPermission();
}
```

---

## Permissions

### Android

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### iOS

```xml
<!-- Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show your position on the map and track deliveries.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location access to track your position while delivering.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

---

## State Management

### LocationState

```dart
class LocationState {
  final bool isTracking;
  final bool hasPermission;
  final bool isServiceEnabled;
  final Position? lastPosition;
  final DateTime? lastUploadTime;
  final int queuedUpdatesCount;
  final bool isOnline;
  final String? error;
}
```

### Providers

| Provider | Type | Description |
|----------|------|-------------|
| `locationServiceProvider` | LocationService | Service instance |
| `locationProvider` | StateNotifier | State management |
| `isTrackingProvider` | bool | Tracking status |
| `hasLocationPermissionProvider` | bool | Permission status |
| `lastKnownPositionProvider` | Position? | Latest position |

---

## Flow Diagram

```
Driver starts shift
        │
        ▼
┌───────────────────┐
│ Check Permission  │
└─────────┬─────────┘
          │
    ┌─────┴─────┐
    │ Granted?  │
    └─────┬─────┘
       No │ Yes
    ┌─────┴─────┐
    ▼           ▼
┌────────┐  ┌────────────┐
│Request │  │Start Stream│
│Permiss │  └─────┬──────┘
└────────┘        │
                  ▼
          ┌────────────────┐
          │ Position Update│◀───────────┐
          └───────┬────────┘            │
                  │                     │
                  ▼                     │
          ┌────────────────┐            │
          │  Rate Limited? │            │
          └───────┬────────┘            │
             Yes  │  No                 │
          ┌───────┴───────┐             │
          ▼               ▼             │
       [Skip]      ┌────────────┐       │
                   │   Online?  │       │
                   └─────┬──────┘       │
                    Yes  │  No          │
                   ┌─────┴─────┐        │
                   ▼           ▼        │
            ┌──────────┐ ┌──────────┐   │
            │ API POST │ │ Add to   │   │
            └────┬─────┘ │  Queue   │   │
                 │       └──────────┘   │
                 │                      │
                 ▼                      │
          [Continue Loop] ─────────────┘
```

---

## Troubleshooting

### Issue: Location not updating

**Causes:**
1. Permission not granted
2. Location services disabled
3. Driver not on shift
4. Rate limited

**Solution:**
- Check `hasLocationPermissionProvider`
- Check `LocationState.isServiceEnabled`
- Ensure shift is started first

### Issue: Queue growing large

**Causes:**
1. Prolonged offline period
2. API errors

**Solution:**
- Queue will auto-upload when online
- Check `queuedUpdatesCount` in state
- Queue limited to 100, oldest dropped

### Issue: Battery drain

**Causes:**
1. Too frequent updates
2. High accuracy setting

**Solution:**
- Distance filter prevents stationary updates
- Rate limiting reduces API calls
- Stop tracking when shift ends

---

## Best Practices

1. **Always stop tracking** when shift ends
2. **Check permissions** before starting
3. **Handle offline gracefully** - queue handles this
4. **Monitor queue size** for debugging
5. **Don't override rate limits** - server has limits too
