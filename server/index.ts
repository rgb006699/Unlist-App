import express from "express";

const app = express();
app.listen(3001, "127.0.0.1", () => {
  console.log("Unlist API on http://127.0.0.1:3001");
});
