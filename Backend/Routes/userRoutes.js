const express = require('express');
const router = express.Router();

const {
  newUser,
  getUserDetails,
  getUserMessages,
  addNewMessage
} = require('../controllers/userController');

router.post('/newUser', newUser);
router.get('/getUserDetails/:id', getUserDetails);
router.get('/getUserMessages/:id', getUserMessages);
router.post('/addNewMessage', addNewMessage);

module.exports = router;