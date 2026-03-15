# 🩺 Laali — Maternal Care Project (MCP)

A voice-first maternal health assistant application built in Kannada (and English) to help pregnant women access reliable health information, track pregnancy progress, and keep their data private.

---

## 🌟 Key Features

- 🗣️ Voice-first interaction (Kannada + English)
- 🤖 AI-powered maternal health guidance
- 📅 Pregnancy tracking via LMP date
- 👤 Automatic user recognition
- 🔒 Anonymous/Private mode
- 💬 Conversation history storage
- 🗄️ PostgreSQL backend for persistence
- 🌐 REST API backend (Node.js + Express)

---

## 🧭 Repository Layout (Current)

```
/ (repo root)
├── backend/                    # Node.js + Express API
│   ├── connections/            # DB connection logic
│   ├── controller/             # Request handlers / business logic
│   ├── routes/                 # API route definitions
│   ├── package.json
│   ├── server.js
│   └── ...
├── frontend/                   # Flutter app
│   ├── lib/                    # Dart source code
│   ├── android/                # Android build
│   ├── ios/ (if present)       # iOS build (may be generated)
│   ├── web/                    # Web build assets
│   ├── windows/                # Windows build
│   ├── pubspec.yaml
│   └── ...
└── README.md                   # This file
```

> 🔎 Note: The Flutter app lives under `frontend/` and the Node.js backend lives under `backend/`.

---

## 🚀 Getting Started (All-in-One)

### 1) Clone repository

```bash
git clone https://github.com/DT-khpt/Laali.git
cd maternal-care-project
```

---

## 🧩 Backend (Node.js + Express + PostgreSQL)

### ✅ Prerequisites

- Node.js (v18+ recommended)
- PostgreSQL running locally (or remote)
- npm (bundled with Node.js)

### 1) Install dependencies

```bash
cd backend
npm install
```

### 2) Configure environment

Create a file at `backend/.env` (do not commit this file).

Example `backend/.env`:

```env
PORT=5000

DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=maternal_care_db

JWT_SECRET=super_secret_key
AI_API_KEY=your_ai_api_key
```

> ⚠️ Make sure `backend/.env` is ignored by Git. If the repo does not already include it, add it to `.gitignore`.

### 3) Database setup

Run these SQL commands in your PostgreSQL instance (adjust to your schema):

```sql
CREATE DATABASE maternal_care_db;

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  phone VARCHAR(15),
  lmp_date DATE,
  anonymous BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE messages (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  message TEXT,
  response TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 4) Run the backend server

```bash
cd backend
npm start
```

By default the API will run at:

```
http://localhost:5000
```

---

## 📱 Frontend (Flutter)

### ✅ Prerequisites

- Flutter SDK (latest stable)
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code
- Android SDK
- Xcode (macOS, for iOS builds)

### 1) Install dependencies

```bash
cd frontend
flutter pub get
```

### 2) Configure API base URL

In the Flutter code, update the backend base URL if needed (typically in `lib/config/api_config.dart` or similar).

For Android emulator:

```dart
const String baseUrl = "http://10.0.2.2:5000/api";
```

For a physical device (or connecting to a remote backend):

```dart
const String baseUrl = "http://YOUR_LOCAL_IP:5000/api";
```

### 3) Run the app

```bash
cd frontend
flutter run
```

---

## 🔐 Security Notes

- Never commit `.env` or secret keys (API keys, JWT secrets).
- Use strong secrets and rotate them regularly.
- Validate/escape all input at the API boundary.
- Use HTTPS in production.

---

## 🧪 Testing

- Backend tests (if present) can be run under `backend/`.
- Frontend widget/unit tests live under `frontend/test/`.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a pull request

---

## 📦 Future Improvements

- Trimester-based AI recommendations
- Push notifications
- Offline voice mode
- Real-time chat (WebSockets)
- Cloud deployment (Render / AWS / Railway)


---

# 📄 License

This project is licensed under the MIT License.
