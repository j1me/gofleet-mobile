# GoFleet Driver Mobile App Documentation

Complete Flutter integration guide for the Driver mobile application.

## Table of Contents

1. [Application Overview](#application-overview)
2. [Role Overview](#role-overview)
3. [API Configuration](#api-configuration)
4. [Authentication](#authentication)
5. [API Reference](#api-reference)
6. [Location Tracking](#location-tracking)
7. [Error Handling](#error-handling)
8. [Best Practices](#best-practices)
9. [Flutter Code Examples](#flutter-code-examples)

---

## Application Overview

### What is GoFleet?

GoFleet is a **multi-tenant SaaS platform** for fleet management and delivery operations. It enables organizations (tenants) to manage their delivery fleets, assign orders to drivers, and track deliveries in real-time.

### System Architecture

GoFleet follows a multi-tenant architecture where:

- **Tenants** are separate organizations (companies) using the platform
- Each tenant has complete **data isolation** - drivers only see their tenant's assignments
- **Tenant Admins** create orders and assignments for drivers
- **Drivers** use mobile apps to receive assignments and deliver orders
- **Host Admins** manage the platform and all tenants

### Core Concepts

- **Tenants**: Organizations using the platform (e.g., "Acme Delivery Co")
- **Drivers**: Mobile app users who deliver orders
- **Orders**: Delivery requests with customer information and drop-off locations
  - Status flow: `unassigned` → `assigned` → `out_for_delivery` → `delivered`/`failed`/`cancelled`
- **Assignments**: Batched groups of orders assigned to a driver
  - Status flow: `created` → `started` → `completed`/`cancelled`
- **Stops**: Individual order deliveries within an assignment (with sequence)
- **Shifts**: Driver work periods (must start shift before receiving assignments)

### System Flow

```
1. Driver signs up with phone + password
2. Tenant Admin invites driver by phone number
3. Driver sees pending invitation and accepts
4. Driver logs in with phone + password
5. Driver starts shift (required before receiving assignments)
6. Tenant Admin creates assignment (groups orders for driver)
7. Driver receives assignment via mobile app
8. Driver starts assignment (begins deliveries)
   - Assignment status: started
   - Orders status: out_for_delivery
9. Driver navigates to delivery locations
10. Driver updates location in real-time (while on shift)
11. Driver marks order as delivered/failed (with GPS proof)
    - Order status: delivered/failed
    - Stop status: delivered/failed
    - Delivery event created with location
12. When all stops complete, assignment status: completed
13. Driver ends shift
```

### How Driver Mobile App Fits Into the Ecosystem

The Driver mobile app is the **field operations interface** where:

- Drivers sign up with phone + password (email optional)
- Drivers receive and accept/reject tenant invitations
- Drivers manage their shifts (start/end)
- Drivers receive assignments from dispatchers
- Drivers view order details and navigate to delivery locations
- Drivers update order status with GPS proof of delivery
- Drivers send real-time location updates (for dispatcher tracking)
- Drivers cannot create orders or assignments (that's Tenant Admin's job)

### Key Features

- **Secure Authentication**: Phone + password login (email optional)
- **Shift Management**: Start/end shifts to control availability
- **Assignment Viewing**: See assigned orders with sequence
- **Order Details**: View customer information and delivery addresses
- **GPS Navigation**: Integration with maps for route guidance
- **Delivery Proof**: Mark deliveries with GPS coordinates
- **Real-Time Location**: Automatic location updates while on shift
- **Offline Support**: Handle network interruptions gracefully

---

## Role Overview

### Driver Responsibilities

As a Driver, you manage deliveries in the field:

1. **Shift Management**
   - Start shift when beginning work
   - End shift when done for the day
   - Must be on shift to receive assignments and send location updates

2. **Assignment Management**
   - View active assignment (if assigned)
   - See all stops (orders) in sequence
   - Start assignment when beginning deliveries

3. **Order Delivery**
   - View order details (customer, address, notes)
   - Navigate to delivery location
   - Mark order as delivered or failed
   - Add delivery notes (optional)

4. **Location Tracking**
   - Automatically send location updates while on shift
   - Location updates required for dispatcher visibility
   - Rate limited to prevent excessive API calls

### Permissions

- ✅ View own profile and assignments
- ✅ Start/end shifts
- ✅ View assigned orders
- ✅ Update order status (delivered/failed)
- ✅ Send location updates (while on shift)
- ❌ Cannot create orders or assignments
- ❌ Cannot view other drivers' data
- ❌ Cannot access tenant admin features

---

## API Configuration

### Production Environment

```
Base URL: https://api.gofleet.cloud
API Version: v1 (implicit)
Content-Type: application/json
```

### Development Environment

```
Base URL: http://localhost:3000
Swagger UI: http://localhost:3000/docs
```

### Flutter Configuration

```dart
// config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'https://api.gofleet.cloud';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration locationUpdateInterval = Duration(seconds: 10);
}
```

---

## Authentication

### Overview

Driver authentication uses **phone + password** login with JWT tokens issued by the backend. The authentication flow is:

1. Sign up with phone + password (+ optional email) → Receive `access_token` and `refresh_token`
2. Accept tenant invitations to join organizations
3. Login with phone + password (+ optional device_id) → Receive `access_token` and `refresh_token`
4. Include `access_token` in all API requests
5. When `access_token` expires, use `refresh_token` to get new tokens
6. Logout invalidates the `refresh_token`

### Token Details

- **Access Token**: Short-lived (1 hour), used for API requests
- **Refresh Token**: Long-lived (30 days), used to obtain new access tokens
- **Token Format**: JWT (JSON Web Token)
- **Device ID**: Optional unique device identifier (recommended for security)

### Login Flow

```dart
// 1. Login
POST /auth/driver/login
Body: {
  "phone": "1234567890",
  "password": "securepassword123",
  "device_id": "device-uuid-optional"
}

Response:
{
  "access_token": "eyJhbGc...",
  "refresh_token": "abc123...",
  "driver": {
    "id": "uuid",
    "tenant_id": "uuid",
    "name": "John Driver",
    "phone": "1234567890",
    "status": "active"
  }
}
```

### Making Authenticated Requests

Include the access token in the `Authorization` header:

```dart
headers: {
  'Authorization': 'Bearer $accessToken',
  'Content-Type': 'application/json'
}
```

### Token Refresh Flow

```dart
// When access token expires (401 response)
POST /auth/driver/refresh
Body: {
  "refresh_token": "abc123..."
}

Response:
{
  "access_token": "new_token...",
  "refresh_token": "new_refresh_token..."
}
```

### Logout Flow

```dart
POST /auth/driver/logout
Body: {
  "refresh_token": "abc123..."
}

Response:
{
  "success": true
}
```

### Drivers Without Tenant Memberships

When a driver signs up or loses all tenant memberships, they receive a token with no active tenant. These drivers can still:

1. **View pending invitations** - `GET /driver/invitations`
2. **Accept/reject invitations** - `POST /driver/invitations/:invitationId/accept` (use the `id` from the invitations list)
3. **Update password** - `POST /driver/password`

After accepting an invitation:
1. Call `POST /auth/driver/refresh` to get a new token with the tenant
2. Or login again to get updated token with tenant list

### Handling No-Tenant State in Flutter

```dart
// After login, check if driver has any tenants
if (loginResponse.activeTenant == null && loginResponse.tenants.isEmpty) {
  // Show "no organization" state
  // Prompt to check invitations
  final invitations = await api.getInvitations();
  if (invitations.isNotEmpty) {
    // Show invitation list
  } else {
    // Show "waiting for invitation" message
  }
}
```

---

## API Reference

### Authentication Endpoints

#### Login

Authenticate as a driver using phone + password.

```http
POST /auth/driver/login
Content-Type: application/json
```

**Request Body:**
```json
{
  "phone": "1234567890",
  "password": "securepassword123",
  "device_id": "device-uuid-optional"
}
```

**Field Requirements:**
- `phone`: Required, 10-15 characters
- `password`: Required, 8-128 characters
- `device_id`: Optional, unique device identifier (recommended)

**Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "abc123def456...",
  "driver": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "tenant_id": "660e8400-e29b-41d4-a716-446655440000",
    "name": "John Driver",
    "phone": "1234567890",
    "status": "active"
  }
}
```

**Error Responses:**
- `401 INVALID_CREDENTIALS`: Wrong phone or password
- `403 TENANT_SUSPENDED`: Tenant account is suspended
- `403 TENANT_TERMINATED`: Tenant account is terminated
- `400 VALIDATION_ERROR`: Invalid phone/password format

---

#### Update Password

Change the driver's password.

```http
POST /driver/password
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "current_password": "old-password",
  "new_password": "new-password"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Password updated successfully. Please log in again."
}
```

**Error Responses:**
- `401 INVALID_CREDENTIALS`: Current password is incorrect
- `400 VALIDATION_ERROR`: New password doesn't meet requirements

**Notes:**
- All sessions are invalidated after password change
- Driver will need to log in again

---

### Invitation Endpoints

Drivers can view and respond to tenant invitations.

#### List Pending Invitations

Get all pending invitations from tenants.

```http
GET /driver/invitations
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "data": [
    {
      "id": "uuid",
      "tenant_id": "uuid",
      "tenant_name": "Acme Delivery Co",
      "invited_at": "2024-01-15T12:00:00.000Z",
      "status": "pending"
    }
  ]
}
```

#### Accept Invitation

Accept an invitation to join a tenant. Use the `id` field from the invitations list response. Returns new tokens with the tenant embedded so the driver can immediately use tenant-scoped endpoints.

```http
POST /driver/invitations/:invitationId/accept
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Path Parameters:**
- `invitationId`: The invitation ID (`id` field from `GET /driver/invitations`)

**Request Body:**
```json
{
  "refresh_token": "current_refresh_token..."
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "You have joined the organization",
  "access_token": "new_access_token_with_tenant...",
  "refresh_token": "new_refresh_token...",
  "tenant": {
    "id": "uuid",
    "name": "Acme Delivery Co",
    "status": "active"
  }
}
```

**Important:** After accepting, store the new tokens immediately:
```dart
final response = await api.acceptInvitation(invitationId, refreshToken);
await tokenStorage.saveTokens(
  accessToken: response.accessToken,
  refreshToken: response.refreshToken,
);
// Now driver can use tenant-scoped endpoints (shift, assignments, etc.)
```

**Error Responses:**
- `401 UNAUTHORIZED`: Invalid refresh token
- `404 NOT_FOUND`: Invitation not found or does not belong to driver
- `409 CONFLICT`: No pending invitation found (already accepted/rejected)

#### Reject Invitation

Reject an invitation from a tenant. Use the `id` field from the invitations list response.

```http
POST /driver/invitations/:invitationId/reject
Authorization: Bearer <access_token>
```

**Path Parameters:**
- `invitationId`: The invitation ID (`id` field from `GET /driver/invitations`)

**Response (200):**
```json
{
  "success": true,
  "message": "Invitation declined"
}
```

**Error Responses:**
- `404 NOT_FOUND`: Invitation not found or does not belong to driver
- `409 CONFLICT`: No pending invitation found (already accepted/rejected)

---

#### Refresh Token

Get new access and refresh tokens.

```http
POST /auth/driver/refresh
Content-Type: application/json
```

**Request Body:**
```json
{
  "refresh_token": "abc123def456..."
}
```

**Response (200):**
```json
{
  "access_token": "new_access_token...",
  "refresh_token": "new_refresh_token..."
}
```

**Error Responses:**
- `401 TOKEN_EXPIRED`: Refresh token expired or invalid
- `403 TENANT_SUSPENDED`: Tenant account is suspended
- `403 TENANT_TERMINATED`: Tenant account is terminated

---

#### Logout

Invalidate refresh token.

```http
POST /auth/driver/logout
Content-Type: application/json
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "refresh_token": "abc123def456..."
}
```

**Response (200):**
```json
{
  "success": true
}
```

---

### Profile Endpoints

#### Get Profile

Get current driver profile information.

```http
GET /driver/me
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "660e8400-e29b-41d4-a716-446655440000",
  "name": "John Driver",
  "phone": "1234567890",
  "status": "active",
  "shift_started_at": "2024-01-15T08:00:00.000Z",
  "last_seen_at": "2024-01-15T12:30:00.000Z"
}
```

**Note**: `shift_started_at` is `null` if driver is not currently on shift.

---

### Shift Management Endpoints

#### Start Shift

Start a driver shift (required before receiving assignments).

```http
POST /driver/shift/start
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "shift_started_at": "2024-01-15T08:00:00.000Z"
}
```

**Error Responses:**
- `409 CONFLICT`: Shift already started

---

#### End Shift

End the current driver shift.

```http
POST /driver/shift/end
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "success": true
}
```

**Note**: Ending shift stops location updates and makes driver unavailable for new assignments.

---

### Assignment Endpoints

#### Get Active Assignment

Get the driver's current active assignment with all stops.

```http
GET /driver/assignments/active
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "id": "aa0e8400-e29b-41d4-a716-446655440000",
  "status": "started",
  "assigned_at": "2024-01-15T08:30:00.000Z",
  "started_at": "2024-01-15T09:00:00.000Z",
  "stops": [
    {
      "id": "dd0e8400-e29b-41d4-a716-446655440000",
      "sequence": 1,
      "status": "pending",
      "order": {
        "id": "990e8400-e29b-41d4-a716-446655440000",
        "customer_name": "Jane Customer",
        "drop_address": "123 Main St, City, State 12345",
        "drop_lat": 40.7128,
        "drop_lng": -74.0060,
        "notes": "Leave at door",
        "status": "out_for_delivery"
      }
    },
    {
      "id": "ee0e8400-e29b-41d4-a716-446655440000",
      "sequence": 2,
      "status": "delivered",
      "completed_at": "2024-01-15T10:00:00.000Z",
      "order": {
        "id": "bb0e8400-e29b-41d4-a716-446655440000",
        "customer_name": "Bob Customer",
        "drop_address": "456 Oak Ave",
        "drop_lat": 40.7580,
        "drop_lng": -73.9855,
        "status": "delivered"
      }
    }
  ]
}
```

**Error Responses:**
- `404 NOT_FOUND`: No active assignment

**Note**: Stops are ordered by `sequence`. Only one assignment can be active at a time.

---

#### Start Assignment

Start the driver's active assignment (transitions from `created` to `started` status). This begins the delivery process and updates all orders in the assignment to `out_for_delivery` status.

```http
POST /driver/assignments/active/start
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "id": "aa0e8400-e29b-41d4-a716-446655440000",
  "status": "started",
  "assigned_at": "2024-01-15T08:30:00.000Z",
  "started_at": "2024-01-15T09:00:00.000Z"
}
```

**Error Responses:**
- `404 NOT_FOUND`: No active assignment found
- `400 BAD_REQUEST`: Assignment already started or invalid status transition

**Note**: Starting an assignment updates all orders in the assignment to `out_for_delivery` status. The assignment must be in `created` status to be started.

---

### Order Endpoints

#### Get Order Details

Get details for a specific order (must be in driver's assignment).

```http
GET /driver/orders/:orderId
Authorization: Bearer <access_token>
```

**Path Parameters:**
- `orderId` (required): UUID of the order

**Response (200):**
```json
{
  "id": "990e8400-e29b-41d4-a716-446655440000",
  "customer_name": "Jane Customer",
  "drop_address": "123 Main St, City, State 12345",
  "drop_lat": 40.7128,
  "drop_lng": -74.0060,
  "notes": "Leave at door",
  "status": "out_for_delivery"
}
```

**Error Responses:**
- `404 NOT_FOUND`: Order not found
- `403 FORBIDDEN`: Order is not assigned to this driver

---

#### Update Order Status

Mark an order as delivered or failed. **Requires idempotency key**.

```http
POST /driver/orders/:orderId/status
Authorization: Bearer <access_token>
Idempotency-Key: unique-key-789
Content-Type: application/json
```

**Path Parameters:**
- `orderId` (required): UUID of the order

**Request Body:**
```json
{
  "status": "delivered",
  "lat": 40.7128,
  "lng": -74.0060,
  "occurred_at": "2024-01-15T10:30:00.000Z",
  "notes": "Left with neighbor"
}
```

**Field Requirements:**
- `status`: Required, `delivered` or `failed`
- `lat`: Required, -90 to 90 (GPS latitude)
- `lng`: Required, -180 to 180 (GPS longitude)
- `occurred_at`: Required, ISO 8601 timestamp
- `notes`: Optional, max 1000 characters

**Response (200):**
```json
{
  "order_id": "990e8400-e29b-41d4-a716-446655440000",
  "status": "delivered",
  "event_id": "ff0e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**
- `400 VALIDATION_ERROR`: Invalid input
- `400 MISSING_IDEMPOTENCY_KEY`: Idempotency-Key header required
- `400 NO_ACTIVE_ASSIGNMENT`: Driver has no active assignment
- `404 NOT_FOUND`: Order not found
- `409 IDEMPOTENCY_CONFLICT`: Same key used with different request body

**Note**: This creates a delivery event with GPS proof. The order status and stop status are updated automatically.

---

### Location Tracking Endpoints

#### Update Location

Update driver's current location. **Only works when driver is on shift**.

```http
POST /driver/location
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "lat": 40.7128,
  "lng": -74.0060,
  "speed": 25.5,
  "heading": 180,
  "accuracy": 10,
  "captured_at": "2024-01-15T10:00:00.000Z"
}
```

**Field Requirements:**
- `lat`: Required, -90 to 90
- `lng`: Required, -180 to 180
- `speed`: Optional, speed in m/s
- `heading`: Optional, direction in degrees (0-360)
- `accuracy`: Optional, GPS accuracy in meters
- `captured_at`: Optional, ISO 8601 timestamp (defaults to now)

**Response (200):**
```json
{
  "success": true,
  "updated_at": "2024-01-15T10:00:00.000Z"
}
```

**Error Responses:**
- `409 DRIVER_NOT_ON_DUTY`: Driver must start shift first
- `400 VALIDATION_ERROR`: Invalid coordinates
- `429 RATE_LIMIT_EXCEEDED`: Too many location updates (rate limited to 2 per 10 seconds)

**Rate Limiting**: Location updates are limited to 2 requests per 10 seconds per driver.

---

## Location Tracking

### Overview

Location tracking enables dispatchers to see driver locations in real-time. Drivers must:

1. **Start shift** (required)
2. **Send location updates** periodically (every 5-10 seconds recommended)
3. **Include GPS metadata** (speed, heading, accuracy) when available

### Implementation Strategy

#### 1. Request Location Permissions

```dart
// Request location permissions
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestLocationPermission() async {
  final status = await Permission.location.request();
  return status.isGranted;
}
```

#### 2. Get Current Location

```dart
import 'package:geolocator/geolocator.dart';

Future<Position?> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services disabled
    return null;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return null;
    }
  }

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
```

#### 3. Track Location Updates

```dart
import 'package:geolocator/geolocator.dart';

StreamSubscription<Position>? positionStream;

void startLocationTracking() {
  positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    ),
  ).listen((Position position) {
    // Send to API
    updateLocation(position);
  });
}

void stopLocationTracking() {
  positionStream?.cancel();
  positionStream = null;
}
```

#### 4. Send Location Updates

```dart
Future<void> updateLocation(Position position) async {
  // Only send if on shift
  if (!isOnShift) return;

  // Rate limit: max 2 per 10 seconds
  if (lastLocationUpdate != null) {
    final elapsed = DateTime.now().difference(lastLocationUpdate!);
    if (elapsed.inSeconds < 5) return; // Skip if too soon
  }

  try {
    await apiClient.updateLocation(
      lat: position.latitude,
      lng: position.longitude,
      speed: position.speed,
      heading: position.heading,
      accuracy: position.accuracy,
    );
    lastLocationUpdate = DateTime.now();
  } catch (e) {
    // Handle error (network, rate limit, etc.)
    // Queue for retry if needed
  }
}
```

### Best Practices

1. **Check Shift Status**: Only send location updates when on shift
2. **Rate Limiting**: Respect API rate limits (2 per 10 seconds)
3. **Distance Filter**: Use distance filter to reduce updates when stationary
4. **Battery Optimization**: Balance update frequency with battery usage
5. **Error Handling**: Handle network errors gracefully, queue updates for retry
6. **Background Updates**: Use background location updates when app is minimized

---

## Error Handling

### Error Response Format

All errors follow this structure:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {}
  }
}
```

### Common Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `VALIDATION_ERROR` | 400 | Request validation failed |
| `BAD_REQUEST` | 400 | Invalid operation |
| `MISSING_IDEMPOTENCY_KEY` | 400 | Idempotency-Key header required |
| `NO_ACTIVE_ASSIGNMENT` | 400 | Driver has no active assignment |
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `INVALID_CREDENTIALS` | 401 | Wrong phone or password |
| `TOKEN_EXPIRED` | 401 | Access token expired (use refresh token) |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `TENANT_SUSPENDED` | 403 | Tenant account is suspended |
| `TENANT_TERMINATED` | 403 | Tenant account is terminated |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource conflict (e.g., shift already started) |
| `DRIVER_NOT_ON_DUTY` | 409 | Driver must start shift first |
| `IDEMPOTENCY_CONFLICT` | 409 | Idempotency key reused with different request |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests (location updates) |
| `INTERNAL_ERROR` | 500 | Unexpected server error |

### Handling Errors

```dart
try {
  final response = await apiClient.updateOrderStatus(
    orderId: orderId,
    status: 'delivered',
    lat: position.latitude,
    lng: position.longitude,
  );
} on ApiException catch (e) {
  switch (e.code) {
    case 'UNAUTHORIZED':
    case 'TOKEN_EXPIRED':
      // Refresh token and retry
      await refreshToken();
      break;
    case 'DRIVER_NOT_ON_DUTY':
      // Show error: must start shift
      showError('Please start your shift first');
      break;
    case 'RATE_LIMIT_EXCEEDED':
      // Wait and retry
      await Future.delayed(Duration(seconds: 5));
      break;
    case 'IDEMPOTENCY_CONFLICT':
      // Generate new key and retry
      idempotencyKey = generateIdempotencyKey();
      break;
    default:
      // Show generic error
      showError(e.message);
  }
} catch (e) {
  // Network error or other exception
  showError('Network error. Please check your connection.');
}
```

---

## Best Practices

### 1. Token Management

- **Store securely**: Use secure storage (flutter_secure_storage)
- **Refresh proactively**: Refresh tokens before expiration
- **Handle refresh failures**: If refresh fails, redirect to login

```dart
// Check token expiration
bool isTokenExpiringSoon(String token) {
  final payload = _decodeJwt(token);
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
  final fiveMinutes = Duration(minutes: 5);
  return DateTime.now().isAfter(expiresAt.subtract(fiveMinutes));
}
```

### 2. Offline Support

- **Queue operations**: Queue API calls when offline
- **Sync on reconnect**: Sync queued operations when connection restored
- **Cache data**: Cache assignments and orders locally
- **Show offline indicator**: Inform user when offline

### 3. Location Tracking

- **Check permissions**: Always check location permissions
- **Handle errors**: Handle GPS errors gracefully
- **Optimize battery**: Balance accuracy with battery usage
- **Respect rate limits**: Don't exceed API rate limits

### 4. Idempotency

- **Always use keys**: For order status updates
- **Store keys**: Save keys with orders for retries
- **Generate UUIDs**: Use UUID v4 for unique keys

### 5. User Experience

- **Loading states**: Show loading indicators for async operations
- **Error messages**: Show clear, actionable error messages
- **Confirmation dialogs**: Confirm destructive actions (end shift, mark failed)
- **Offline mode**: Show offline indicator and queue actions

### 6. Performance

- **Image optimization**: Optimize images before upload
- **Lazy loading**: Load assignment details on demand
- **Cache**: Cache frequently accessed data
- **Debounce**: Debounce user inputs

---

## Flutter Code Examples

### API Client

```dart
// lib/api/driver_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import '../models/driver.dart';
import '../models/assignment.dart';
import '../models/order.dart';
import '../storage/token_storage.dart';

class DriverApiClient {
  final String baseUrl;
  final TokenStorage tokenStorage;

  DriverApiClient({
    this.baseUrl = ApiConfig.baseUrl,
    required this.tokenStorage,
  });

  Future<Map<String, String>> _getHeaders() async {
    final token = await tokenStorage.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _getHeaders();
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamedResponse = await request.send().timeout(
      ApiConfig.requestTimeout,
    );
    final response = await http.Response.fromStream(streamedResponse);

    // Handle token expiration
    if (response.statusCode == 401) {
      await _refreshToken();
      // Retry request
      return _request(method, endpoint, body: body, extraHeaders: extraHeaders);
    }

    return response;
  }

  Future<void> _refreshToken() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('No refresh token');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/driver/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
    } else {
      // Refresh failed, clear tokens
      await tokenStorage.clearTokens();
      throw Exception('Token refresh failed');
    }
  }

  // Authentication
  Future<DriverLoginResponse> login({
    required String phone,
    required String pin,
    String? deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/driver/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'pin': pin,
        if (deviceId != null) 'device_id': deviceId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      return DriverLoginResponse.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        code: error['error']['code'],
        message: error['error']['message'],
      );
    }
  }

  Future<void> logout() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken != null) {
      await http.post(
        Uri.parse('$baseUrl/auth/driver/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    }
    await tokenStorage.clearTokens();
  }

  // Profile
  Future<Driver> getProfile() async {
    final response = await _request('GET', '/driver/me');
    if (response.statusCode == 200) {
      return Driver.fromJson(jsonDecode(response.body));
    } else {
      throw _handleError(response);
    }
  }

  // Shift Management
  Future<DateTime> startShift() async {
    final response = await _request('POST', '/driver/shift/start');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return DateTime.parse(data['shift_started_at']);
    } else {
      throw _handleError(response);
    }
  }

  Future<void> endShift() async {
    final response = await _request('POST', '/driver/shift/end');
    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  // Assignments
  Future<Assignment?> getActiveAssignment() async {
    final response = await _request('GET', '/driver/assignments/active');
    if (response.statusCode == 200) {
      return Assignment.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null; // No active assignment
    } else {
      throw _handleError(response);
    }
  }

  // Orders
  Future<Order> getOrder(String orderId) async {
    final response = await _request('GET', '/driver/orders/$orderId');
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw _handleError(response);
    }
  }

  Future<OrderStatusUpdateResponse> updateOrderStatus({
    required String orderId,
    required String status,
    required double lat,
    required double lng,
    required DateTime occurredAt,
    String? notes,
  }) async {
    final idempotencyKey = const Uuid().v4();
    final response = await _request(
      'POST',
      '/driver/orders/$orderId/status',
      body: {
        'status': status,
        'lat': lat,
        'lng': lng,
        'occurred_at': occurredAt.toIso8601String(),
        if (notes != null) 'notes': notes,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );

    if (response.statusCode == 200) {
      return OrderStatusUpdateResponse.fromJson(jsonDecode(response.body));
    } else {
      throw _handleError(response);
    }
  }

  // Location Tracking
  Future<void> updateLocation({
    required double lat,
    required double lng,
    double? speed,
    double? heading,
    double? accuracy,
    DateTime? capturedAt,
  }) async {
    final response = await _request(
      'POST',
      '/driver/location',
      body: {
        'lat': lat,
        'lng': lng,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (accuracy != null) 'accuracy': accuracy,
        if (capturedAt != null) 'captured_at': capturedAt.toIso8601String(),
      },
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Exception _handleError(http.Response response) {
    final error = jsonDecode(response.body);
    return ApiException(
      code: error['error']['code'],
      message: error['error']['message'],
    );
  }
}

class ApiException implements Exception {
  final String code;
  final String message;

  ApiException({required this.code, required this.message});

  @override
  String toString() => message;
}
```

### Token Storage

```dart
// lib/storage/token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
```

### Location Service

```dart
// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import '../api/driver_api.dart';
import '../storage/shift_storage.dart';

class LocationService {
  final DriverApiClient apiClient;
  final ShiftStorage shiftStorage;
  StreamSubscription<Position>? _positionStream;
  DateTime? _lastUpdate;
  static const Duration _updateInterval = Duration(seconds: 10);

  LocationService({
    required this.apiClient,
    required this.shiftStorage,
  });

  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  void startTracking() async {
    if (!await checkPermissions()) {
      return;
    }

    final isOnShift = await shiftStorage.isOnShift();
    if (!isOnShift) {
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _updateLocation(position);
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _lastUpdate = null;
  }

  Future<void> _updateLocation(Position position) async {
    // Rate limiting
    if (_lastUpdate != null) {
      final elapsed = DateTime.now().difference(_lastUpdate!);
      if (elapsed < _updateInterval) {
        return;
      }
    }

    final isOnShift = await shiftStorage.isOnShift();
    if (!isOnShift) {
      stopTracking();
      return;
    }

    try {
      await apiClient.updateLocation(
        lat: position.latitude,
        lng: position.longitude,
        speed: position.speed,
        heading: position.heading,
        accuracy: position.accuracy,
      );
      _lastUpdate = DateTime.now();
    } catch (e) {
      // Handle error (log, queue for retry, etc.)
      print('Location update failed: $e');
    }
  }
}
```

### Provider Example

```dart
// lib/providers/driver_provider.dart
import 'package:flutter/foundation.dart';
import '../api/driver_api.dart';
import '../models/driver.dart';
import '../models/assignment.dart';

class DriverProvider with ChangeNotifier {
  final DriverApiClient apiClient;
  
  Driver? _driver;
  Assignment? _activeAssignment;
  bool _isOnShift = false;
  bool _isLoading = false;

  DriverProvider({required this.apiClient});

  Driver? get driver => _driver;
  Assignment? get activeAssignment => _activeAssignment;
  bool get isOnShift => _isOnShift;
  bool get isLoading => _isLoading;

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      _driver = await apiClient.getProfile();
      _isOnShift = _driver?.shift_started_at != null;
      notifyListeners();
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startShift() async {
    try {
      await apiClient.startShift();
      await loadProfile();
      await loadActiveAssignment();
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  Future<void> endShift() async {
    try {
      await apiClient.endShift();
      _isOnShift = false;
      _activeAssignment = null;
      notifyListeners();
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  Future<void> loadActiveAssignment() async {
    try {
      _activeAssignment = await apiClient.getActiveAssignment();
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    required double lat,
    required double lng,
    String? notes,
  }) async {
    try {
      await apiClient.updateOrderStatus(
        orderId: orderId,
        status: status,
        lat: lat,
        lng: lng,
        occurredAt: DateTime.now(),
        notes: notes,
      );
      // Reload assignment to get updated status
      await loadActiveAssignment();
    } catch (e) {
      // Handle error
      rethrow;
    }
  }
}
```

### Widget Example

```dart
// lib/screens/assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/driver_provider.dart';
import '../models/assignment.dart';

class AssignmentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DriverProvider>(
      builder: (context, provider, child) {
        final assignment = provider.activeAssignment;

        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (assignment == null) {
          return Center(
            child: Text('No active assignment'),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Assignment'),
            subtitle: Text('Status: ${assignment.status}'),
          ),
          body: ListView.builder(
            itemCount: assignment.stops.length,
            itemBuilder: (context, index) {
              final stop = assignment.stops[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${stop.sequence}'),
                ),
                title: Text(stop.order.customerName),
                subtitle: Text(stop.order.dropAddress),
                trailing: _buildStatusChip(stop.status),
                onTap: () {
                  if (stop.status == 'pending') {
                    _showDeliveryDialog(context, provider, stop.order);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'delivered':
        color = Colors.green;
        break;
      case 'failed':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
  }

  void _showDeliveryDialog(
    BuildContext context,
    DriverProvider provider,
    Order order,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark as Delivered?'),
        content: Text('Customer: ${order.customerName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Get current location
              final position = await Geolocator.getCurrentPosition();
              // Update status
              await provider.updateOrderStatus(
                orderId: order.id,
                status: 'delivered',
                lat: position.latitude,
                lng: position.longitude,
              );
            },
            child: Text('Delivered'),
          ),
        ],
      ),
    );
  }
}
```

---

## Testing

### Example cURL Commands

**Login:**
```bash
curl -X POST https://api.gofleet.cloud/auth/driver/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "1234567890",
    "password": "securepassword123"
  }'
```

**Start Shift:**
```bash
curl -X POST https://api.gofleet.cloud/driver/shift/start \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Get Active Assignment:**
```bash
curl https://api.gofleet.cloud/driver/assignments/active \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Update Order Status:**
```bash
curl -X POST https://api.gofleet.cloud/driver/orders/ORDER_ID/status \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Idempotency-Key: unique-key-123" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "delivered",
    "lat": 40.7128,
    "lng": -74.0060,
    "occurred_at": "2024-01-15T10:30:00.000Z"
  }'
```

**Update Location:**
```bash
curl -X POST https://api.gofleet.cloud/driver/location \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "lat": 40.7128,
    "lng": -74.0060,
    "speed": 25.5,
    "heading": 180,
    "accuracy": 10
  }'
```

---

## Support

- **API Documentation**: See `/docs` endpoint when running locally
- **Backend Documentation**: See `backend/docs/API.md`
- **Flutter Packages**: 
  - `http`: HTTP client
  - `geolocator`: Location services
  - `permission_handler`: Permission management
  - `flutter_secure_storage`: Secure token storage
- **Issues**: Contact backend team or check GitHub Issues

---

**Last Updated**: 2024-01-15
