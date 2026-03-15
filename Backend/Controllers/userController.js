// Create New User
exports.newUser = async (req, res) => {
  const pool = req.app.locals.pool;
  const { name, date_set } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO users (name, date_set)
       VALUES ($1, $2)
       RETURNING *`,
      [name, date_set]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Get User Details
exports.getUserDetails = async (req, res) => {
  const pool = req.app.locals.pool;
  const userId = req.params.id;

  try {
    const result = await pool.query(
      `SELECT * FROM users WHERE id = $1`,
      [userId]
    );

    if (result.rows.length === 0)
      return res.status(404).json({ message: 'User not found' });

    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Get User Messages
exports.getUserMessages = async (req, res) => {
  const pool = req.app.locals.pool;
  const userId = req.params.id;

  try {
    const result = await pool.query(
      `SELECT * FROM messages WHERE user_id = $1 ORDER BY time DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Add New Message
exports.addNewMessage = async (req, res) => {
  const pool = req.app.locals.pool;
  const { user_id, message } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO messages (user_id, message)
       VALUES ($1, $2)
       RETURNING *`,
      [user_id, message]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};