import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      '/ws': { target: 'ws://127.0.0.1:8080', ws: true },
      '/health': 'http://127.0.0.1:8080',
    },
  },
  build: { chunkSizeWarningLimit: 1100 },
});
