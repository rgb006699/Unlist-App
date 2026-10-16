import { existsSync } from "node:fs";
import { createApp } from "./app";

// `npm start` builds the web app into dist/ and sets UNLIST_SERVE_BUILD, so
// the API also serves the UI on this port. `npm run dev` uses Vite instead.
const staticDir = process.env.UNLIST_SERVE_BUILD && existsSync("dist/index.html") ? "dist" : undefined;

const app = createApp({ dataDir: process.env.UNLIST_DATA_DIR ?? "data", brokersPath: "brokers.json", staticDir });

app.listen(3001, "127.0.0.1", () => {
  console.log(staticDir ? "Unlist is running at http://localhost:3001" : "Unlist API on http://127.0.0.1:3001");
});
