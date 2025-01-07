const express = require("express");
const router = express.Router();

// import individual routes
const testRoutes = require("./test");
const authRoutes = require("./auth");
const userRoutes = require("./users");
const chatRoutes = require("./chat");

// make use of imported routes
router.use('/api', testRoutes);
router.use('/api', authRoutes);
router.use('/api/users', userRoutes);
router.use('/api/chat', chatRoutes);

module.exports = router;
