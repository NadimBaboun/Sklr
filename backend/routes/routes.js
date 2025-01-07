const express = require("express");
const router = express.Router();

// import individual routes
const testRoutes = require("./test");

// make use of imported routes
router.use('/api', testRoutes);

module.exports = router;
