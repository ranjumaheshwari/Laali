const express = require('express');
const { Pool } = require('pg');
require('dotenv').config();
const createDatabaseIfNotExists = require('./Connection/db');

const userRoutes = require('./Routes/userRoutes');

const app = express();
app.use(express.json());

async function startServer() {
  await createDatabaseIfNotExists();

  const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
  });

  await pool.query('SELECT NOW()');
  console.log('Connected to database');

  // Create tables
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      date_set DATE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS messages (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      message TEXT NOT NULL,
      time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  console.log('Tables ensured');

  // Make pool accessible in routes
  app.locals.pool = pool;

  app.use('/api', userRoutes);

  app.get('/', (req, res) => {
    res.send("Hello World");
  });

  app.listen(process.env.PORT, () => {
    console.log(`Server running on port ${process.env.PORT}`);
  });
}

startServer().catch(err => {
  console.error('Startup error:', err);
});