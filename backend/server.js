const express = require("express");
const cors = require("cors");
const routes = require("./routes/routes");
require("dotenv").config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());

app.use(express.json());

app.use(routes);

app.listen(port, () => {
    console.log(`Server running @ port ${port}`);
});
