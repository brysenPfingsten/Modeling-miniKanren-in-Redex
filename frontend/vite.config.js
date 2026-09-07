import { env } from 'node:process';
export default {
  server: {
    proxy: {
      '/api': {
        target: env.VITE_API_URL || 'http://racket-server:5000',
        changeOrigin: true,
        rewrite: path => path.replace(/^\/api/, '')
      }
    },
    host: true, // Important for Docker (bind to 0.0.0.0)
    port: 5173
  }
}
