import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  // Served from https://tomklotzpro.github.io/pixelheim/ - keep this base
  // unconditional (a command-conditional base breaks `vite preview`).
  // CI overrides it for PR preview deploys (pr-preview/pr-N subpaths).
  base: process.env.VITE_BASE ?? '/pixelheim/',
  plugins: [react()],
})
