# smart-city-backend
Spring Boot backend for AI Smart City Reporting System, AI-powered civic reporting mobile app enabling citizens to submit urban issues, track resolutions, and discover nearby parks/activities. Features smart priority analysis, real-time notifications, interactive status mapping, and an admin dashboard for municipal management.

# 🔐 Authentication Module — V1.0

---

## Overview

The authentication module covers the full registration and login flow for the Smart City application, implemented across both the backend (Spring Boot) and frontend (Flutter), with all endpoints tested and integrated end-to-end.

---

## ✅ What Was Completed in V1.0

### Backend (Spring Boot)

- `User.java` — JPA entity mapped to the `users` table in PostgreSQL, with BCrypt-hashed password storage and automatic `createdAt` timestamp via `@PrePersist`
- `UserRepository.java` — Spring Data JPA repository with custom `findByEmail` and `existsByEmail` query methods
- `RegisterRequest.java` / `LoginRequest.java` / `AuthResponse.java` — DTO layer for incoming and outgoing auth data
- `AuthService.java` — Business logic for registration (email uniqueness check, password hashing, user creation) and login (credential verification, account status check, JWT generation)
- `JwtUtil.java` — JWT (JSON Web Token) generation using JJWT library with 24-hour expiration and signed claims (email, role, userId)
- `AuthController.java` — REST endpoints: `POST /api/auth/register` (201) and `POST /api/auth/login` (200)
- `GlobalExceptionHandler.java` — Centralized exception handling returning structured JSON error responses
- `SecurityConfig.java` — Spring Security configuration with stateless JWT sessions and open auth endpoints
- `AppConfig.java` — BCryptPasswordEncoder bean definition

### Frontend (Flutter)

- `auth_service.dart` — HTTP client service connecting Flutter to the Spring Boot backend via `http` package
- `register_screen.dart` — Registration form with client-side validation, connected to real backend
- `login_screen.dart` — Login form with credential submission, JWT token storage via `shared_preferences`, and navigation to home screen on success
- End-to-end integration tested on Android emulator (Pixel 7 API 34)

---

## 🔗 API Endpoints

| Method | Endpoint | Description | Success Status |
|--------|----------|-------------|----------------|
| POST | `/api/auth/register` | Register a new user account | 201 Created |
| POST | `/api/auth/login` | Login with email and password | 200 OK |

---

## ❌ Error Responses

| Exception | HTTP Status | Trigger |
|-----------|-------------|---------|
| `EmailAlreadyExistsException` | 409 Conflict | Email already registered |
| `UserNotFoundException` | 404 Not Found | Email not in database |
| `InvalidCredentialsException` | 401 Unauthorized | Wrong password |
| `AccountNotVerifiedException` | 403 Forbidden | Account not yet verified |
| `MethodArgumentNotValidException` | 400 Bad Request | Invalid/missing input fields |

---

## ⚠️ Known Limitations in V1.0

### Email Verification — Manual Only

- Every newly registered account has `enabled = false` by default as required by FR-01
- Email verification via a real verification link sent to the user's inbox is **not yet implemented**
- To activate an account manually during development and testing, run the following command directly on the database:

```bash
docker exec -it smartcity-postgres psql -U smartcity_user -d smartcity \
  -c "UPDATE users SET enabled = true WHERE email = 'user@example.com';"
```

- Full email verification (token generation, SMTP email delivery, verification endpoint) is planned for **V1.1**

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|------------|
| Backend Framework | Spring Boot 3.5 |
| Database | PostgreSQL 15 (Docker) |
| ORM | Hibernate / Spring Data JPA |
| Security | Spring Security 6 |
| Password Hashing | BCrypt |
| Token | JWT via JJWT 0.11.5 |
| Frontend | Flutter (Dart) |
| HTTP Client | `http` package |
| Token Storage | `shared_preferences` |

---

## 🗂️ Module Structure

```
backend/
├── config/         → AppConfig, SecurityConfig
├── controller/     → AuthController
├── dto/            → RegisterRequest, LoginRequest, AuthResponse
├── exception/      → GlobalExceptionHandler + 4 custom exceptions
├── model/          → User, Role
├── repository/     → UserRepository
├── security/       → JwtUtil
└── service/        → AuthService

frontend/
└── lib/
    ├── screens/    → login_screen.dart, register_screen.dart
    ├── services/   → auth_service.dart
    └── widgets/    → app_widgets.dart
```

---

## 🚀 How to Run Locally

**1. Start the database and Redis:**
```bash
cd backend
docker-compose up -d
```

**2. Run the Spring Boot backend:**
```
IntelliJ IDEA → Run BackendApplication
Backend starts on: http://localhost:8080
```

**3. Run the Flutter frontend on Android emulator:**
```bash
cd smart-city-frontend
flutter pub get
flutter run
```

> The Flutter app connects to the backend via `http://10.0.2.2:8080/api/auth`
> (Android emulator localhost alias).
> For a physical device, replace with your machine's local IP address found via `ipconfig`.

---

## 📌 Planned for V1.1

- Real email verification via SMTP (Gmail) with tokenized verification links
- Token expiry handling (24-hour verification window)
- Resend verification email endpoint
- Forgot password / reset password flow