const express = require("express");
const router = express.Router();

// import individual routes
const testRoutes = require("./test");
const authRoutes = require("./auth");
const userRoutes = require("./users");
const chatRoutes = require("./chat");
const sessionRoutes = require("./sessions");
const skillsRoutes = require("./skills");

// make use of imported routes
router.use('/api', testRoutes);
router.use('/api', authRoutes);
router.use('/api/users', userRoutes);
router.use('/api/chat', chatRoutes);
router.use('/api/sessions', sessionRoutes);
router.use('/api/skills', skillsRoutes);

module.exports = router;
