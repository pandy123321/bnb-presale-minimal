import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      "@": "/src",
    },
  },
  server: {
    port: 5174,
    proxy: {
      "/api": "http://localhost:4000",
      "/admin-api": "http://localhost:4000",
    },
  },
});
