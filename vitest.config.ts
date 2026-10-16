import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    include: ["{shared,server,web}/**/*.test.{ts,tsx}"],
    environment: "node",
    globals: true,
    setupFiles: ["./vitest.setup.ts"],
  },
});
