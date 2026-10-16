import { createApp } from "./app";

const app = createApp({ dataDir: process.env.UNLIST_DATA_DIR ?? "data", brokersPath: "brokers.json" });

app.listen(3001, "127.0.0.1", () => {
  console.log("Unlist API on http://127.0.0.1:3001");
});
