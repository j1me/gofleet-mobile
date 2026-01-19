# GoFleet Driver Mobile App - Implementation Documentation

Complete technical documentation for the GoFleet Driver mobile application built with Flutter.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Project Structure](#project-structure)
3. [Design System](#design-system)
4. [Data Models](#data-models)
5. [State Management](#state-management)
6. [API Integration](#api-integration)
7. [Navigation](#navigation)
8. [Screens Reference](#screens-reference)
9. [Services](#services)
10. [Configuration](#configuration)

---

## Architecture Overview

The app follows a **layered architecture** pattern with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Screens   │  │   Widgets   │  │     Providers       │  │
│  │   (UI)      │  │ (Reusable)  │  │  (State Mgmt)       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                      DOMAIN LAYER                           │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    Data Models                       │    │
│  │   Driver, Tenant, Assignment, Order, Stop, etc.     │    │
│  └─────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│                       DATA LAYER                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ API Client  │  │Token Storage│  │   Local Storage     │  │
│  │   (Dio)     │  │  (Secure)   │  │ (SharedPrefs/Hive)  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                     EXTERNAL SERVICES                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ GoFleet API │  │ Google Maps │  │      Geolocator     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Unidirectional Data Flow**: State flows from providers to UI
2. **Dependency Injection**: Services injected via Riverpod providers
3. **Immutable State**: All state objects are immutable
4. **Separation of Concerns**: Clear boundaries between layers

---

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── app.dart                       # MaterialApp configuration
│
├── config/                        # Configuration
│   ├── api_config.dart            # API URLs and timeouts
│   ├── maps_config.dart           # Google Maps styling
│   └── theme/
│       ├── app_colors.dart        # Color palette
│       ├── app_theme.dart         # ThemeData
│       └── app_typography.dart    # Text styles
│
├── core/                          # Core utilities
│   └── errors/
│       └── api_exception.dart     # Error handling
│
├── data/                          # Data layer
│   └── models/
│       ├── models.dart            # Barrel export
│       ├── driver.dart            # Driver model
│       ├── tenant.dart            # Tenant model
│       ├── invitation.dart        # Invitation model
│       ├── assignment.dart        # Assignment model
│       ├── stop.dart              # Stop model
│       ├── order.dart             # Order model
│       ├── auth_tokens.dart       # Auth tokens
│       └── login_response.dart    # Login response
│
├── presentation/                  # UI layer
│   ├── providers/
│   │   ├── providers.dart         # Core providers
│   │   ├── auth_provider.dart     # Authentication state
│   │   └── driver_provider.dart   # Driver/shift state
│   │
│   ├── screens/
│   │   ├── splash/
│   │   │   └── splash_screen.dart
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── invitations/
│   │   │   └── invitations_screen.dart
│   │   ├── no_tenant/
│   │   │   └── no_tenant_screen.dart
│   │   ├── tenants/
│   │   │   └── tenant_list_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── assignment/
│   │   │   └── assignment_screen.dart
│   │   ├── order/
│   │   │   └── order_detail_screen.dart
│   │   ├── delivery/
│   │   │   ├── delivery_screen.dart
│   │   │   └── delivery_success_screen.dart
│   │   ├── profile/
│   │   │   ├── profile_screen.dart
│   │   │   └── change_password_screen.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   │
│   └── widgets/
│       └── common/
│           ├── app_button.dart
│           ├── app_text_field.dart
│           └── loading_overlay.dart
│
├── router/
│   └── app_router.dart            # GoRouter configuration
│
└── services/
    ├── api/
    │   └── api_client.dart        # Dio HTTP client
    ├── navigation/
    │   └── navigation_service.dart # Google Maps launcher
    └── storage/
        ├── token_storage.dart     # Secure token storage
        └── local_storage.dart     # SharedPreferences
```

---

## Design System

### Color Palette

```dart
// Primary Colors
black         = #000000  // Main background
charcoal      = #141414  // Secondary background
darkGray      = #1C1C1C  // Card backgrounds
mediumGray    = #282828  // Elevated surfaces
lightGray     = #3D3D3D  // Borders, dividers

// Accent Colors
primaryGreen  = #34D399  // Success, active, primary actions
accentBlue    = #3B82F6  // Links, secondary actions
warningYellow = #FBBF24  // Warnings, pending states
errorRed      = #EF4444  // Errors, failed, destructive

// Text Colors
textPrimary   = #FFFFFF  // White
textSecondary = #A3A3A3  // Light gray
textMuted     = #737373  // Darker gray
```

### Typography Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| displayLarge | 32px | Bold | Hero titles |
| displayMedium | 28px | Bold | Page titles |
| displaySmall | 24px | Bold | Section titles |
| headlineLarge | 24px | SemiBold | Card titles |
| headlineMedium | 20px | SemiBold | Subtitles |
| titleLarge | 18px | Medium | List item titles |
| titleMedium | 16px | Medium | Button text |
| bodyLarge | 16px | Regular | Body text |
| bodyMedium | 14px | Regular | Secondary text |
| labelMedium | 12px | SemiBold | Labels, badges |

### Component Specifications

#### Buttons

| Type | Background | Border | Text Color |
|------|------------|--------|------------|
| Primary | primaryGreen | None | black |
| Outlined | Transparent | lightGray | textPrimary |
| Danger | Transparent | errorRed | errorRed |
| Text | Transparent | None | primaryGreen |

- Height: 56px (standard), 44px (compact)
- Border radius: 12px
- Padding: 24px horizontal

#### Cards

- Background: darkGray (#1C1C1C)
- Border: 1px lightGray (#3D3D3D)
- Border radius: 16px
- Padding: 16-20px

#### Text Fields

- Background: darkGray (#1C1C1C)
- Border: 1px lightGray (unfocused), 2px primaryGreen (focused)
- Border radius: 12px
- Padding: 20px horizontal, 18px vertical

---

## Data Models

### Driver

```dart
class Driver {
  final String id;
  final String? tenantId;
  final String name;
  final String phone;
  final String? email;
  final String status;           // 'active', 'inactive'
  final DateTime? shiftStartedAt;
  final DateTime? lastSeenAt;

  bool get isOnShift => shiftStartedAt != null;
  bool get isActive => status == 'active';
  Duration? get shiftDuration;
}
```

### Tenant

```dart
class Tenant {
  final String id;
  final String name;
  final String status;    // 'trial', 'active', 'suspended', 'terminated'
  final DateTime? joinedAt;

  bool get isActive => status == 'active';
}
```

### Assignment

```dart
class Assignment {
  final String id;
  final AssignmentStatus status;  // created, started, completed, cancelled
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<Stop> stops;

  int get totalStops;
  int get completedStops;
  int get pendingStops;
  double get completionPercentage;
  Stop? get nextStop;
  List<Stop> get sortedStops;
}
```

### Stop

```dart
class Stop {
  final String id;
  final int sequence;
  final StopStatus status;  // pending, delivered, failed
  final DateTime? completedAt;
  final Order order;

  bool get isCompleted;
  bool get isPending;
}
```

### Order

```dart
class Order {
  final String id;
  final String customerName;
  final String dropAddress;
  final double dropLat;
  final double dropLng;
  final String? notes;
  final OrderStatus status;

  bool get canDeliver;
}
```

---

## State Management

### Auth Provider

Manages authentication state including login, logout, and tenant management.

```dart
class AuthState {
  final AuthStatus status;      // initial, loading, authenticated, unauthenticated, noTenant
  final Driver? driver;
  final List<Tenant> tenants;
  final Tenant? activeTenant;
  final List<Invitation> invitations;
  final String? error;
  final bool isLoading;
}

class AuthNotifier extends StateNotifier<AuthState> {
  // Methods
  Future<void> checkAuthState();
  Future<void> login({phone, password, deviceId});
  Future<void> signup({name, phone, password, email});
  Future<void> logout();
  Future<void> acceptInvitation(tenantId);
  Future<void> rejectInvitation(tenantId);
  Future<void> switchTenant(tenantId);
  Future<void> leaveTenant(tenantId);
}
```

### Driver Provider

Manages driver state including shift and assignment.

```dart
class DriverState {
  final Driver? driver;
  final Assignment? activeAssignment;
  final bool isLoading;
  final String? error;

  bool get isOnShift;
  bool get hasActiveAssignment;
}

class DriverNotifier extends StateNotifier<DriverState> {
  // Methods
  Future<void> loadProfile();
  Future<void> startShift();
  Future<void> endShift();
  Future<void> loadActiveAssignment();
  Future<void> updateOrderStatus({orderId, status, lat, lng, notes});
}
```

### Provider Hierarchy

```
apiClientProvider          # API client singleton
tokenStorageProvider       # Secure token storage
localStorageProvider       # Preferences storage
        │
        ▼
authProvider              # Authentication state
        │
        ▼
driverProvider            # Driver/shift/assignment state
```

---

## API Integration

### API Client

The `ApiClient` class handles all HTTP communication with the GoFleet backend.

#### Configuration

```dart
BaseOptions(
  baseUrl: 'http://64.227.172.248:3000',
  connectTimeout: Duration(seconds: 30),
  receiveTimeout: Duration(seconds: 30),
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
)
```

#### Interceptors

1. **AuthInterceptor**: Adds Bearer token to requests, handles 401 responses
2. **LoggingInterceptor**: Logs requests/responses for debugging

#### Token Refresh Flow

```
Request → 401 Response
    │
    ▼
Is refresh endpoint? → Yes → Clear tokens, throw error
    │ No
    ▼
Refresh token
    │
    ▼
Retry original request with new token
```

### Endpoint Methods

| Method | Endpoint | Description |
|--------|----------|-------------|
| `login()` | POST `/auth/driver/login` | Login with phone/password |
| `signup()` | POST `/public/driver/signup` | Register new driver |
| `refreshToken()` | POST `/auth/driver/refresh` | Refresh access token |
| `logout()` | POST `/auth/driver/logout` | Invalidate refresh token |
| `getProfile()` | GET `/driver/me` | Get driver profile |
| `startShift()` | POST `/driver/shift/start` | Start shift |
| `endShift()` | POST `/driver/shift/end` | End shift |
| `getInvitations()` | GET `/driver/invitations` | List pending invitations |
| `acceptInvitation()` | POST `/driver/invitations/:id/accept` | Accept invitation |
| `rejectInvitation()` | POST `/driver/invitations/:id/reject` | Reject invitation |
| `getTenants()` | GET `/driver/tenants` | List joined tenants |
| `switchTenant()` | POST `/driver/tenants/switch` | Switch active tenant |
| `leaveTenant()` | DELETE `/driver/tenants/:id` | Leave tenant |
| `getActiveAssignment()` | GET `/driver/assignments/active` | Get active assignment |
| `getOrder()` | GET `/driver/orders/:id` | Get order details |
| `updateOrderStatus()` | POST `/driver/orders/:id/status` | Update order status |
| `updateLocation()` | POST `/driver/location` | Update driver location |

### Error Handling

```dart
class ApiException {
  final String code;      // e.g., 'INVALID_CREDENTIALS'
  final String message;   // Human-readable message
  final int? statusCode;
  final Map<String, dynamic>? details;
}

// Common error codes
VALIDATION_ERROR        // 400 - Request validation failed
UNAUTHORIZED           // 401 - Missing/invalid token
INVALID_CREDENTIALS    // 401 - Wrong phone/password
TOKEN_EXPIRED          // 401 - Access token expired
FORBIDDEN              // 403 - Insufficient permissions
TENANT_SUSPENDED       // 403 - Tenant account suspended
NOT_FOUND              // 404 - Resource not found
DRIVER_NOT_ON_DUTY     // 409 - Must start shift first
RATE_LIMIT_EXCEEDED    // 429 - Too many requests
```

---

## Navigation

### Route Structure

```dart
AppRoutes.splash              = '/'
AppRoutes.onboarding          = '/onboarding'
AppRoutes.login               = '/login'
AppRoutes.signup              = '/signup'
AppRoutes.invitations         = '/invitations'
AppRoutes.tenants             = '/tenants'
AppRoutes.noTenant            = '/no-tenant'
AppRoutes.home                = '/home'
AppRoutes.assignment          = '/assignment'
AppRoutes.orderDetail         = '/orders/:id'
AppRoutes.delivery            = '/deliver/:id'
AppRoutes.deliverySuccess     = '/deliver/:id/success'
AppRoutes.profile             = '/profile'
AppRoutes.changePassword      = '/profile/password'
AppRoutes.settings            = '/settings'
```

### Navigation Flow

```
                    ┌─────────────┐
                    │   Splash    │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
      ┌─────────────┐ ┌─────────┐ ┌─────────────┐
      │ Onboarding  │ │  Login  │ │    Home     │
      └──────┬──────┘ └────┬────┘ └─────────────┘
             │             │
             └──────┬──────┘
                    ▼
           ┌─────────────────┐
           │     Login       │
           └────────┬────────┘
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
┌─────────────┐ ┌─────────┐ ┌─────────────┐
│ Invitations │ │No Tenant│ │    Home     │
└─────────────┘ └─────────┘ └──────┬──────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
       ┌─────────────┐      ┌─────────────┐     ┌─────────────┐
       │ Assignment  │      │   Profile   │     │  Settings   │
       └──────┬──────┘      └─────────────┘     └─────────────┘
              │
              ▼
       ┌─────────────┐
       │Order Detail │
       └──────┬──────┘
              │
              ▼
       ┌─────────────┐
       │  Delivery   │
       └──────┬──────┘
              │
              ▼
       ┌─────────────┐
       │   Success   │
       └─────────────┘
```

### Auth-Based Redirects

The router uses `redirect` to handle authentication state:

| Current State | From Auth Route | From Protected Route | Action |
|---------------|-----------------|---------------------|--------|
| Unauthenticated | - | Yes | Redirect to `/login` |
| Authenticated | Yes | - | Redirect to `/home` |
| No Tenant | Auth routes | Protected routes | Redirect to `/no-tenant` |

---

## Screens Reference

### 1. Splash Screen (`/`)

**Purpose**: Initialize app, validate tokens, determine initial route

**Logic**:
1. Show animated logo
2. Initialize local storage
3. Check for existing tokens
4. Validate tokens with API
5. Route based on auth state

### 2. Onboarding Screen (`/onboarding`)

**Purpose**: Introduce app features to first-time users

**Content**:
- 3 pages with illustrations
- Skip button
- Next/Get Started button
- Page indicator dots

### 3. Login Screen (`/login`)

**Purpose**: Authenticate existing drivers

**Fields**:
- Phone number (with country code prefix)
- Password (with visibility toggle)

**Actions**:
- Sign In button
- Create Account link

### 4. Signup Screen (`/signup`)

**Purpose**: Register new drivers

**Fields**:
- Full Name (required)
- Phone Number (required)
- Email (optional)
- Password (required)
- Confirm Password (required)
- Terms checkbox (required)

### 5. Invitations Screen (`/invitations`)

**Purpose**: View and respond to tenant invitations

**Features**:
- List of pending invitations
- Accept/Decline buttons per invitation
- Empty state when no invitations
- Refresh capability

### 6. No Tenant Screen (`/no-tenant`)

**Purpose**: Shown when driver has no active organization

**Features**:
- Informational message
- Check Invitations button
- Logout link

### 7. Tenant List Screen (`/tenants`)

**Purpose**: View and switch between organizations

**Features**:
- Current tenant with active indicator
- Other tenants with Switch/Leave buttons
- Link to pending invitations

### 8. Home Screen (`/home`)

**Purpose**: Main dashboard with shift and assignment status

**States**:
1. **Offline**: "Go Online" button
2. **Online, No Assignment**: Waiting animation, shift timer
3. **Online, Has Assignment**: Next stop card, Navigate/Deliver buttons

### 9. Assignment Screen (`/assignment`)

**Purpose**: View all stops in current assignment

**Features**:
- Progress bar
- Stop list with status indicators
- Navigate/Deliver actions for next stop
- Completed stop history

### 10. Order Detail Screen (`/orders/:id`)

**Purpose**: View complete order information

**Sections**:
- Map preview
- Customer name
- Delivery address (with Copy/Open Maps)
- Delivery notes
- Order status

### 11. Delivery Screen (`/deliver/:id`)

**Purpose**: Mark order as delivered or failed

**Features**:
- Delivered/Failed toggle
- Failure reason selection (when failed)
- Notes input
- GPS verification
- Confirm button

### 12. Delivery Success Screen (`/deliver/:id/success`)

**Purpose**: Confirmation after delivery

**Content**:
- Success animation
- Next delivery preview (if any)
- Navigate to Next button
- View All Stops button
- Progress indicator

### 13. Profile Screen (`/profile`)

**Purpose**: View and manage driver profile

**Sections**:
- Avatar and name
- Phone and email info
- Change Password link
- Organization link
- Invitations link (with badge)
- Logout button

### 14. Change Password Screen (`/profile/password`)

**Purpose**: Update driver password

**Fields**:
- Current Password
- New Password
- Confirm New Password

**Notes**:
- Logs out after successful change
- Shows password requirements

### 15. Settings Screen (`/settings`)

**Purpose**: App preferences

**Sections**:
- Location (permissions, background updates)
- Notifications (push, sound)
- About (version, terms, privacy)

---

## Services

### Navigation Service

Launches Google Maps for external navigation.

```dart
class NavigationService {
  // Launch turn-by-turn navigation
  static Future<void> navigateToLocation({
    required double lat,
    required double lng,
  });

  // Open location in Google Maps app
  static Future<void> openInMaps({
    required double lat,
    required double lng,
    String? label,
  });
}
```

### Token Storage

Secure storage for JWT tokens using `flutter_secure_storage`.

```dart
class TokenStorage {
  Future<void> saveTokens(AuthTokens tokens);
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<bool> hasTokens();
  Future<void> clearTokens();
}
```

### Local Storage

Non-sensitive preferences using `SharedPreferences`.

```dart
class LocalStorage {
  Future<bool> hasSeenOnboarding();
  Future<void> setHasSeenOnboarding(bool value);
  Future<String?> getLastActiveTenantId();
  Future<void> setLastActiveTenantId(String? id);
  Future<bool> isBackgroundLocationEnabled();
  Future<bool> isPushNotificationsEnabled();
  // ...
}
```

---

## Configuration

### API Configuration

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String prodBaseUrl = 'http://64.227.172.248:3000';
  static const String devBaseUrl = 'http://localhost:3000';
  static const String baseUrl = prodBaseUrl;
  
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration locationUpdateInterval = Duration(seconds: 10);
  static const Duration assignmentPollingInterval = Duration(seconds: 30);
}
```

### Google Maps Configuration

```dart
// lib/config/maps_config.dart
class MapsConfig {
  static const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const String darkMapStyle = '...'; // JSON style for dark mode
}
```

### Required Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show your position and navigate to deliveries.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need background location to track your position while delivering.</string>
```

---

## Testing

### Unit Tests

```bash
flutter test
```

### Integration Tests

```bash
flutter test integration_test
```

### Running the App

```bash
# Development
flutter run

# Release build
flutter run --release
```

---

## Deployment

### Android

```bash
# APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

---

## Changelog

### v1.0.0 (Initial Release)

- Authentication (login, signup, logout)
- Multi-tenant support with invitations
- Shift management (start/end)
- Assignment viewing
- Order delivery with GPS proof
- Google Maps navigation integration
- Profile and settings
- Uber-inspired dark theme
