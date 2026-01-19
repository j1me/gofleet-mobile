# GoFleet Driver Mobile App

A Flutter mobile application for GoFleet delivery drivers to manage shifts, receive assignments, navigate to deliveries, and update order statuses with GPS proof.

## Features

- **Authentication**: Phone + password login with JWT tokens
- **Multi-Tenant Support**: Drivers can work for multiple organizations
- **Invitation System**: Accept/reject tenant invitations from dispatchers
- **Shift Management**: Start/end shifts to control availability
- **Assignment Management**: View assigned orders with sequence
- **GPS Navigation**: Integration with Google Maps for turn-by-turn directions
- **Delivery Proof**: Mark deliveries as completed with GPS coordinates
- **Real-Time Location**: Automatic location updates while on shift
- **Offline Support**: Queue delivery updates when offline

## Requirements

- Flutter 3.0+
- Dart 3.0+
- Android SDK 21+ / iOS 12+
- Google Maps API Key

## Getting Started

### 1. Clone the repository

```bash
git clone <repository-url>
cd gofleet-driver-mobile
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Google Maps API Key

#### Android
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE"/>
```

#### iOS
Edit `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
```

### 4. Run the app

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # App widget with theme
├── config/
│   ├── api_config.dart       # API configuration
│   ├── maps_config.dart      # Google Maps configuration
│   └── theme/
│       ├── app_colors.dart   # Color palette
│       ├── app_theme.dart    # Theme data
│       └── app_typography.dart # Typography styles
├── core/
│   └── errors/
│       └── api_exception.dart # API error handling
├── data/
│   └── models/               # Data models
│       ├── driver.dart
│       ├── tenant.dart
│       ├── invitation.dart
│       ├── assignment.dart
│       ├── stop.dart
│       ├── order.dart
│       └── ...
├── presentation/
│   ├── providers/            # State management
│   │   ├── auth_provider.dart
│   │   └── driver_provider.dart
│   ├── screens/              # UI screens
│   │   ├── auth/
│   │   ├── home/
│   │   ├── assignment/
│   │   ├── delivery/
│   │   └── ...
│   └── widgets/              # Reusable widgets
├── router/
│   └── app_router.dart       # Navigation routes
└── services/
    ├── api/
    │   └── api_client.dart   # API client with Dio
    ├── navigation/
    │   └── navigation_service.dart
    └── storage/
        ├── token_storage.dart
        └── local_storage.dart
```

## API Endpoints

The app communicates with the GoFleet backend API. See [API.md](API.md) for complete API documentation.

### Key Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/driver/login` | POST | Login with phone + password |
| `/public/driver/signup` | POST | Register new driver |
| `/driver/me` | GET | Get driver profile |
| `/driver/shift/start` | POST | Start shift |
| `/driver/shift/end` | POST | End shift |
| `/driver/assignments/active` | GET | Get active assignment |
| `/driver/orders/:id/status` | POST | Update order status |
| `/driver/location` | POST | Update location |

## Screens

| Screen | Route | Description |
|--------|-------|-------------|
| Splash | `/` | App initialization |
| Onboarding | `/onboarding` | First-time user intro |
| Login | `/login` | Phone + password login |
| Signup | `/signup` | New driver registration |
| Invitations | `/invitations` | View/respond to tenant invitations |
| Tenant List | `/tenants` | Switch between organizations |
| No Tenant | `/no-tenant` | Shown when no organization |
| Home | `/home` | Dashboard with shift status |
| Assignment | `/assignment` | Stop list with progress |
| Order Detail | `/orders/:id` | Order information |
| Delivery | `/deliver/:id` | Mark delivered/failed |
| Delivery Success | `/deliver/:id/success` | Confirmation |
| Profile | `/profile` | Driver profile |
| Settings | `/settings` | App preferences |

## Design System

The app uses an **Uber-inspired dark theme** with the following design principles:

### Colors
- **Primary**: Green (#34D399) for actions and success states
- **Background**: Black (#000000) with dark gray cards (#1C1C1C)
- **Error**: Red (#EF4444) for failures and destructive actions
- **Warning**: Yellow (#FBBF24) for attention items

### Typography
- **Font**: Inter (Google Fonts)
- **Headings**: Bold weight, large sizes
- **Body**: Regular weight, comfortable reading

## State Management

The app uses **Riverpod** for state management:

- `authProvider`: Authentication state (login, logout, tokens)
- `driverProvider`: Driver state (profile, shift, assignment)

## Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.4.0    # State management
  go_router: ^12.0.0          # Navigation
  dio: ^5.3.0                 # HTTP client
  flutter_secure_storage: ^9.0.0  # Secure token storage
  geolocator: ^10.1.0         # Location services
  google_maps_flutter: ^2.5.0 # Map display
  url_launcher: ^6.2.0        # External navigation
```

## Build

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## License

Copyright © 2024 GoFleet. All rights reserved.
