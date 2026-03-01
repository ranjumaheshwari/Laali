# 🩺 Maternal Care Project (MCP)

A voice-first maternal health assistant application built in Kannada language to help pregnant women access reliable health information and track their pregnancy journey safely and privately.

---

## 🌟 Features

- 🗣️ Voice-first interaction (Kannada + English support)
- 🤖 AI-powered maternal health assistance
- 📅 Pregnancy tracking using LMP date
- 👤 Automatic user recognition
- 🔒 Anonymous mode for privacy
- 💬 Conversation history storage
- 🗄️ PostgreSQL database integration
- 🌐 REST API backend (Node.js + Express)

---

# 🏗️ Project Structure

maternal-care-project/
│
├── Backend/
│   ├── Connection/        # Database configuration
│   ├── Controllers/       # Business logic
│   ├── Routes/            # API routes
│   ├── .env               # Environment variables (DO NOT COMMIT)
│   ├── package.json
│   └── server.js
│
├── android/
├── assets/
├── lib/
├── web/
├── windows/
├── pubspec.yaml
└── README.md

---

# 📱 Frontend Setup (Flutter)

## Prerequisites

- Flutter SDK (latest version)
- Dart SDK
- Android Studio / VS Code
- Android SDK
- Xcode (for iOS – macOS only)

## Installation

1. Clone the repository:

git clone https://github.com/your-username/maternal-care-project.git

2. Navigate to project:

cd maternal-care-project

3. Install dependencies:

flutter pub get

4. Run the app:

flutter run

---

# 🖥️ Backend Setup (Node.js + Express + PostgreSQL)

## Prerequisites

- Node.js (v18+ recommended)
- PostgreSQL installed and running
- npm

---

## 1️⃣ Install Backend Dependencies

cd Backend  
npm install  

If required:

npm install express cors dotenv pg bcrypt jsonwebtoken  

---

## 2️⃣ Create `.env` File

Inside the `Backend/` folder create a file named:

.env

### Example `.env` Configuration

PORT=5000

DB_HOST=localhost  
DB_PORT=5432  
DB_USER=postgres  
DB_PASSWORD=your_password  
DB_NAME=maternal_care_db  

JWT_SECRET=super_secret_key  
AI_API_KEY=your_ai_api_key  

⚠️ Important: Add this to `.gitignore`

Backend/node_modules  
Backend/.env  

---

## 3️⃣ Database Setup

Create PostgreSQL database:

CREATE DATABASE maternal_care_db;

Example tables:

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

---

## 4️⃣ Start Backend Server

cd Backend  
node server.js  

or  

npm start  

Server runs at:

http://localhost:5000

---

# 🔗 Connecting Flutter to Backend

For Android Emulator:

const String baseUrl = "http://10.0.2.2:5000/api";

For Physical Device:

const String baseUrl = "http://YOUR_LOCAL_IP:5000/api";

---

# 🔐 Security Notes

- Never commit `.env` file
- Use strong JWT secret
- Hash passwords using bcrypt
- Validate API inputs
- Use HTTPS in production

---

# 🚀 Future Improvements

- Trimester-based AI suggestions
- Push notifications
- Offline voice mode
- Real-time chat (WebSocket)
- Cloud deployment (Render / AWS / Railway)

---

# 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create a new branch
3. Commit your changes
4. Submit a Pull Request

---

# 📄 License

This project is licensed under the MIT License.
