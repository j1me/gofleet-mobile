# GoFleet API Documentation

Complete API reference for the GoFleet fleet management backend.

## Base URL

- Production: `https://api.gofleet.cloud`
- Development: `http://localhost:3000`
- Swagger UI: `http://localhost:3000/docs`

## Authentication

### Host Admin
```http
Authorization: Bearer <host_jwt>
```

### Tenant Admin
```http
Authorization: Bearer <supabase_jwt>
X-Tenant-Id: <tenant_uuid>
```

**Note:** To get the tenant_id after login, use `GET /auth/me/tenants` (no X-Tenant-Id required).

### Driver
```http
Authorization: Bearer <driver_jwt>
```

---

## Public Endpoints

### Health Check
```http
GET /health
```

**Response (200)**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T12:00:00.000Z"
}
```

### Tenant Self-Signup
```http
POST /public/signup
```

**Request Body**
```json
{
  "tenant_name": "Acme Delivery Co",
  "admin_email": "admin@acme.com",
  "admin_password": "securepassword123",
  "admin_name": "John Admin"
}
```

**Response (201)**
```json
{
  "tenant_id": "uuid",
  "user_id": "uuid"
}
```

**Errors**
- `409 DUPLICATE`: Email already registered

### Driver Self-Signup
```http
POST /public/driver/signup
```

**Request Body**
```json
{
  "name": "John Driver",
  "phone": "1234567890",
  "password": "securepassword123",
  "email": "john@example.com"
}
```

**Response (201)**
```json
{
  "driver": {
    "id": "uuid",
    "name": "John Driver",
    "phone": "1234567890",
    "email": "john@example.com",
    "status": "active"
  },
  "access_token": "jwt...",
  "refresh_token": "token..."
}
```

**Notes:**
- `email` is optional
- `password` must be 8-128 characters
- Driver will see pending tenant invitations after signup

**Errors**
- `409 DUPLICATE`: Phone already registered

---

## Auth Endpoints (Pre-Tenant)

These endpoints only require a Supabase JWT - no `X-Tenant-Id` header needed.

### Get User's Tenants
```http
GET /auth/me/tenants
Authorization: Bearer <supabase_jwt>
```

Returns all tenants the authenticated user belongs to. Use this after Supabase login to determine which tenant(s) the user can access.

**Response (200)**
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "admin@acme.com"
  },
  "tenants": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440000",
      "name": "Acme Delivery Co",
      "status": "active",
      "role": "owner"
    }
  ]
}
```

**Usage:**
- Single tenant: auto-select and use as `X-Tenant-Id`
- Multiple tenants: show tenant picker UI
- No tenants: user is not a member of any organization

**Errors**
- `401 UNAUTHORIZED`: Missing or invalid token

---

## Host Admin Endpoints

### Login
```http
POST /host/auth/login
```

**Request Body**
```json
{
  "email": "host@platform.com",
  "password": "password"
}
```

**Response (200)**
```json
{
  "access_token": "jwt...",
  "refresh_token": "token...",
  "user": {
    "id": "uuid",
    "email": "host@platform.com",
    "role": "host_admin"
  }
}
```

### Refresh Token
```http
POST /host/auth/refresh
```

**Request Body**
```json
{
  "refresh_token": "token..."
}
```

### Logout
```http
POST /host/auth/logout
```

**Request Body**
```json
{
  "refresh_token": "token..."
}
```

### Update Password
```http
POST /host/auth/password
```

**Request Body**
```json
{
  "current_password": "old-password",
  "new_password": "new-password"
}
```

**Response (200)**
```json
{
  "success": true,
  "message": "Password updated successfully. Please log in again."
}
```

**Notes:**
- Requires authentication
- All sessions are invalidated after password change

**Errors**
- `401 INVALID_CREDENTIALS`: Current password is incorrect

### List Tenants
```http
GET /host/tenants?status=active&search=acme&limit=50&offset=0
```

**Query Parameters**
- `status` (optional): Filter by status (`trial`, `active`, `suspended`, `terminated`)
- `search` (optional): Search tenants by name (case-insensitive partial match)
- `limit` (optional): Number of results (1-100, default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response (200)**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Acme Delivery",
      "status": "active",
      "metadata_json": {},
      "created_at": "2024-01-15T12:00:00.000Z"
    }
  ],
  "total": 100,
  "limit": 50,
  "offset": 0
}
```

### Get Tenant Stats
```http
GET /host/tenants/stats
```

**Response (200)**
```json
{
  "total": 50,
  "by_status": {
    "trial": 10,
    "active": 30,
    "suspended": 5,
    "terminated": 5
  }
}
```

### Create Tenant
```http
POST /host/tenants
```

**Request Body**
```json
{
  "name": "New Tenant",
  "status": "trial",
  "metadata": { "plan": "basic" }
}
```

### Get Tenant
```http
GET /host/tenants/:tenantId
```

### Update Tenant
```http
PATCH /host/tenants/:tenantId
```

**Request Body**
```json
{
  "name": "Updated Name",
  "metadata": { "plan": "premium" }
}
```

### Update Tenant Status
```http
POST /host/tenants/:tenantId/status
```

**Request Body**
```json
{
  "status": "suspended"
}
```

### List Host Users
```http
GET /host/users?limit=50&offset=0
```

**Response (200)**
```json
{
  "data": [
    {
      "id": "uuid",
      "email": "admin@platform.com",
      "role": "host_admin",
      "created_at": "2024-01-15T12:00:00.000Z"
    }
  ],
  "total": 5,
  "limit": 50,
  "offset": 0
}
```

### Create Host User
```http
POST /host/users
```

**Request Body**
```json
{
  "email": "newadmin@platform.com",
  "password": "securepassword123"
}
```

### Delete Host User
```http
DELETE /host/users/:userId
```

### List Tenant Members
```http
GET /host/tenants/:tenantId/members?role=admin&status=active&limit=50&offset=0
```

**Response (200)**
```json
{
  "data": [
    {
      "id": "uuid",
      "tenant_id": "uuid",
      "user_id": "uuid",
      "email": "admin@acme.com",
      "name": "John Admin",
      "role": "owner",
      "status": "active",
      "created_at": "2024-01-15T12:00:00.000Z"
    }
  ],
  "total": 3,
  "limit": 50,
  "offset": 0
}
```

### Create Tenant Member
```http
POST /host/tenants/:tenantId/members
```

**Request Body**
```json
{
  "email": "newuser@acme.com",
  "password": "securepassword123",
  "name": "Jane User",
  "role": "admin"
}
```

### Update Tenant Member
```http
PATCH /host/tenants/:tenantId/members/:memberId
```

**Request Body**
```json
{
  "role": "dispatcher",
  "status": "inactive"
}
```

### Delete Tenant Member
```http
DELETE /host/tenants/:tenantId/members/:memberId
```

---

## Tenant Admin Endpoints

All admin endpoints require:
- `Authorization: Bearer <supabase_jwt>`
- `X-Tenant-Id: <tenant_uuid>`

### Authentication

#### Update Password
```http
POST /admin/auth/password
```

**Request Body**
```json
{
  "current_password": "old-password",
  "new_password": "new-password"
}
```

**Response (200)**
```json
{
  "success": true,
  "message": "Password updated successfully. Please log in again."
}
```

### Get Tenant Context
```http
GET /admin/tenant/context
```

**Response (200)**
```json
{
  "user": {
    "id": "uuid",
    "email": "admin@acme.com",
    "role": "owner"
  },
  "tenant": {
    "id": "uuid",
    "name": "Acme Delivery",
    "status": "active",
    "metadata": {}
  }
}
```

### Drivers

#### List Drivers
```http
GET /admin/drivers?status=active&limit=50&offset=0
```

#### Search Driver by Phone
```http
GET /admin/drivers/search?phone=1234567890
```

**Response (200)**
```json
{
  "found": true,
  "driver": {
    "id": "uuid",
    "name": "John Driver",
    "phone": "1234567890",
    "email": "john@example.com",
    "status": "active"
  },
  "is_member": false,
  "membership_status": null
}
```

#### Invite Driver by Phone
```http
POST /admin/drivers/invite
```

**Request Body**
```json
{
  "phone": "1234567890",
  "name": "John Driver"
}
```

**Response (201)**
```json
{
  "type": "membership",
  "message": "Invitation sent to existing driver. They will see it when they log in.",
  "driver_id": "uuid",
  "invitation_id": null
}
```

**Notes:**
- If driver exists: Creates pending membership (driver must accept)
- If driver doesn't exist: Creates phone invitation (auto-claimed on signup)
- `name` is optional (hint for display purposes)

**Errors**
- `409 CONFLICT`: Driver already a member or has pending invitation

#### List Phone Invitations
```http
GET /admin/drivers/invitations?status=pending&limit=50&offset=0
```

Shows invitations for phone numbers that haven't signed up yet.

#### Cancel Phone Invitation
```http
DELETE /admin/drivers/invitations/:invitationId
```

#### Get Driver
```http
GET /admin/drivers/:driverId
```

#### Update Driver
```http
PATCH /admin/drivers/:driverId
```

#### Deactivate Driver
```http
POST /admin/drivers/:driverId/deactivate
```

### Orders

#### List Orders
```http
GET /admin/orders?status=unassigned&limit=50&offset=0
```

#### Create Order
```http
POST /admin/orders
Idempotency-Key: unique-key-123
```

**Request Body**
```json
{
  "external_ref": "SHOP-12345",
  "customer_name": "Jane Customer",
  "drop_address": "123 Main St, City, State 12345",
  "drop_lat": 40.7128,
  "drop_lng": -74.0060,
  "notes": "Leave at door"
}
```

**Response (201)**
```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "external_ref": "SHOP-12345",
  "customer_name": "Jane Customer",
  "drop_address": "123 Main St, City, State 12345",
  "drop_lat": 40.7128,
  "drop_lng": -74.006,
  "notes": "Leave at door",
  "status": "unassigned",
  "created_at": "2024-01-15T12:00:00.000Z"
}
```

#### Get Order
```http
GET /admin/orders/:orderId
```

#### Update Order
```http
PATCH /admin/orders/:orderId
```

#### Cancel Order
```http
POST /admin/orders/:orderId/cancel
```

### Assignments

#### List Assignments
```http
GET /admin/assignments?status=created&driver_id=uuid&limit=50&offset=0
```

#### Create Assignment
```http
POST /admin/assignments
Idempotency-Key: unique-key-456
```

**Request Body**
```json
{
  "driver_id": "uuid",
  "order_ids": ["uuid1", "uuid2", "uuid3"],
  "sequence_mode": "manual",
  "sequence": [0, 1, 2]
}
```

**Response (201)**
```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "driver_id": "uuid",
  "status": "created",
  "assigned_at": "2024-01-15T12:00:00.000Z",
  "stops": [
    {
      "id": "uuid",
      "sequence": 1,
      "status": "pending",
      "order": { ... }
    }
  ]
}
```

#### Get Assignment
```http
GET /admin/assignments/:assignmentId
```

#### Update Assignment
```http
PATCH /admin/assignments/:assignmentId
```

**Request Body**
```json
{
  "driver_id": "new-driver-uuid"
}
```

#### Cancel Assignment
```http
POST /admin/assignments/:assignmentId/cancel
```

### Tracking

#### Get All Driver Locations
```http
GET /admin/tracking/drivers?on_shift_only=true
```

**Response (200)**
```json
{
  "data": [
    {
      "driver_id": "uuid",
      "driver": {
        "id": "uuid",
        "name": "John Driver",
        "status": "active",
        "shift_started_at": "2024-01-15T08:00:00.000Z"
      },
      "lat": 40.7128,
      "lng": -74.006,
      "speed": 25.5,
      "heading": 180,
      "accuracy": 10,
      "updated_at": "2024-01-15T12:00:00.000Z"
    }
  ]
}
```

#### Get Driver Location
```http
GET /admin/tracking/drivers/:driverId
```

### Team Members

#### List Members
```http
GET /admin/members?role=dispatcher&status=active&limit=50&offset=0
```

#### Create Member (Invite)
```http
POST /admin/members
```

**Request Body**
```json
{
  "email": "dispatcher@acme.com",
  "name": "John Dispatcher",
  "role": "dispatcher"
}
```

**Roles:** `owner`, `admin`, `dispatcher`, `viewer`

#### Update Member
```http
PATCH /admin/members/:memberId
```

**Request Body**
```json
{
  "role": "admin",
  "status": "active"
}
```

#### Remove Member
```http
DELETE /admin/members/:memberId
```

## Driver Endpoints

All driver endpoints require:
- `Authorization: Bearer <driver_jwt>`

### Authentication Modes

Driver endpoints use two authentication modes:

| Mode | Endpoints | Tenant Required |
|------|-----------|-----------------|
| **JWT + Tenant** | `/driver/me`, `/driver/shift/*`, `/driver/assignments/*`, `/driver/orders/*`, `/driver/location`, `/driver/tenants/*` | Yes - requires active tenant membership |
| **JWT Only** | `/driver/invitations/*`, `/driver/password` | No - only verifies driver identity |

**Note:** Drivers without any tenant memberships can still access JWT-only endpoints to view/accept invitations.

### Login
```http
POST /auth/driver/login
```

**Request Body**
```json
{
  "phone": "1234567890",
  "password": "securepassword123",
  "device_id": "device-uuid"
}
```

**Response (200)**
```json
{
  "access_token": "jwt...",
  "refresh_token": "token...",
  "driver": {
    "id": "uuid",
    "name": "John Driver",
    "phone": "1234567890",
    "email": "john@example.com",
    "status": "active"
  },
  "tenants": [
    {
      "id": "uuid",
      "name": "Acme Delivery",
      "status": "active"
    },
    {
      "id": "uuid",
      "name": "Fast Logistics",
      "status": "active"
    }
  ],
  "active_tenant": {
    "id": "uuid",
    "name": "Acme Delivery",
    "status": "active"
  }
}
```

**Notes:**
- `tenants` lists all organizations the driver belongs to
- `active_tenant` is the currently selected tenant (null if driver has no tenants)
- Driver can switch between tenants using `/driver/tenants/switch`

### Refresh Token
```http
POST /auth/driver/refresh
```

### Logout
```http
POST /auth/driver/logout
```

### Update Password
```http
POST /driver/password
```

**Request Body**
```json
{
  "current_password": "old-password",
  "new_password": "new-password"
}
```

**Response (200)**
```json
{
  "success": true,
  "message": "Password updated successfully. Please log in again."
}
```

**Notes:**
- All sessions are invalidated after password change

### Get Profile
```http
GET /driver/me
```

### Start Shift
```http
POST /driver/shift/start
```

**Response (200)**
```json
{
  "shift_started_at": "2024-01-15T08:00:00.000Z"
}
```

### End Shift
```http
POST /driver/shift/end
```

### Get Active Assignment
```http
GET /driver/assignments/active
```

**Response (200)**
```json
{
  "id": "uuid",
  "status": "started",
  "assigned_at": "2024-01-15T08:30:00.000Z",
  "started_at": "2024-01-15T09:00:00.000Z",
  "stops": [
    {
      "id": "uuid",
      "sequence": 1,
      "status": "pending",
      "order": {
        "id": "uuid",
        "customer_name": "Jane Customer",
        "drop_address": "123 Main St",
        "drop_lat": 40.7128,
        "drop_lng": -74.006
      }
    }
  ]
}
```

### Get Order Details
```http
GET /driver/orders/:orderId
```

### Update Order Status
```http
POST /driver/orders/:orderId/status
Idempotency-Key: delivery-event-123
```

**Request Body**
```json
{
  "status": "delivered",
  "lat": 40.7128,
  "lng": -74.006,
  "occurred_at": "2024-01-15T10:30:00.000Z",
  "notes": "Left with neighbor"
}
```

**Response (200)**
```json
{
  "order_id": "uuid",
  "status": "delivered",
  "event_id": "uuid"
}
```

### Update Location
```http
POST /driver/location
```

**Request Body**
```json
{
  "lat": 40.7128,
  "lng": -74.006,
  "speed": 25.5,
  "heading": 180,
  "accuracy": 10,
  "captured_at": "2024-01-15T10:00:00.000Z"
}
```

**Response (200)**
```json
{
  "success": true,
  "updated_at": "2024-01-15T10:00:00.000Z"
}
```

**Errors**
- `409 DRIVER_NOT_ON_DUTY`: Must start shift first

### Pending Invitations (JWT-Only Auth)

These endpoints only require driver authentication - no active tenant membership needed.
Drivers can view and respond to tenant invitations even if they have no current tenants.

#### List Pending Invitations
```http
GET /driver/invitations
```

**Response (200)**
```json
{
  "data": [
    {
      "id": "uuid",
      "tenant_id": "uuid",
      "tenant_name": "Acme Delivery",
      "invited_at": "2024-01-15T12:00:00.000Z",
      "status": "pending"
    }
  ]
}
```

#### Accept Invitation
```http
POST /driver/invitations/:invitationId/accept
```

**Path Parameters:**
- `invitationId`: The invitation ID (`id` field from `GET /driver/invitations`)

**Response (200)**
```json
{
  "success": true,
  "message": "You have joined the organization"
}
```

**Error Responses:**
- `404 NOT_FOUND`: Invitation not found or does not belong to driver
- `409 CONFLICT`: No pending invitation found (already accepted/rejected)

#### Reject Invitation
```http
POST /driver/invitations/:invitationId/reject
```

**Path Parameters:**
- `invitationId`: The invitation ID (`id` field from `GET /driver/invitations`)

**Response (200)**
```json
{
  "success": true,
  "message": "Invitation declined"
}
```

**Error Responses:**
- `404 NOT_FOUND`: Invitation not found or does not belong to driver
- `409 CONFLICT`: No pending invitation found (already accepted/rejected)

### Tenant Management (Multi-Tenant Drivers)

Drivers can belong to multiple tenants and switch between them.

#### List My Tenants
```http
GET /driver/tenants
```

**Response (200)**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Acme Delivery",
      "status": "active",
      "joined_at": "2024-01-15T12:00:00.000Z"
    }
  ]
}
```

#### Switch Active Tenant
```http
POST /driver/tenants/switch
X-Refresh-Token: <refresh_token>
```

**Request Body**
```json
{
  "tenant_id": "uuid"
}
```

**Response (200)**
```json
{
  "access_token": "new_jwt...",
  "tenant": {
    "id": "uuid",
    "name": "Fast Logistics",
    "status": "active"
  }
}
```

**Notes:**
- Returns a new access token scoped to the selected tenant
- Include refresh token in `X-Refresh-Token` header

#### Leave Tenant
```http
DELETE /driver/tenants/:tenantId
```

**Response (200)**
```json
{
  "success": true
}
```

---

## Error Responses

All errors follow this format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "details": { }
  }
}
```

### Common Error Codes

| Code | Status | Description |
|------|--------|-------------|
| VALIDATION_ERROR | 400 | Request validation failed |
| BAD_REQUEST | 400 | Invalid operation |
| UNAUTHORIZED | 401 | Missing or invalid auth token |
| INVALID_CREDENTIALS | 401 | Wrong email/password/PIN |
| TOKEN_EXPIRED | 401 | Auth token expired |
| FORBIDDEN | 403 | Insufficient permissions |
| TENANT_SUSPENDED | 403 | Tenant account suspended |
| TENANT_TERMINATED | 403 | Tenant account terminated |
| NOT_FOUND | 404 | Resource not found |
| CONFLICT | 409 | Resource conflict |
| DUPLICATE | 409 | Duplicate resource |
| ORDER_ALREADY_ASSIGNED | 409 | Order has existing assignment |
| DRIVER_NOT_ON_DUTY | 409 | Driver must start shift |
| IDEMPOTENCY_CONFLICT | 409 | Idempotency key reused with different request |
| INVALID_STATUS_TRANSITION | 400 | Invalid status change |
| RATE_LIMIT_EXCEEDED | 429 | Too many requests |
| INTERNAL_ERROR | 500 | Unexpected server error |

---

## Idempotency

The following endpoints require an `Idempotency-Key` header:

- `POST /admin/orders`
- `POST /admin/assignments`
- `POST /driver/orders/:orderId/status`

**Rules:**
- Same key + same request body = cached response returned
- Same key + different request body = 409 IDEMPOTENCY_CONFLICT
- Keys expire after 24 hours
