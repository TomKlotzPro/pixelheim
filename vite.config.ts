import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  // Served from https://tomklotzpro.github.io/pixelheim/
  // (also applies to `vite dev`/`vite preview`, so the app is always at /pixelheim/)
  base: '/pixelheim/',
  plugins: [react()],
})
