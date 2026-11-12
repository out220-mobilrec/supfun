import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
var backend = process.env.VITE_API_PROXY || 'http://localhost:3000';
export default defineConfig({
    plugins: [react()],
    server: {
        port: 5173,
        proxy: {
            '/api': { target: backend, changeOrigin: true },
            '/uploads': { target: backend, changeOrigin: true },
            '/socket.io': { target: backend, changeOrigin: true, ws: true },
        },
    },
    build: {
        outDir: 'dist',
        sourcemap: false,
        chunkSizeWarningLimit: 900,
    },
});
