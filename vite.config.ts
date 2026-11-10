import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { defineConfig } from 'vitest/config'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      // The new service worker waits until the user taps "Recargar" in the
      // update banner (src/app/update-banner.tsx); it never reloads by itself.
      registerType: 'prompt',
      // Off: the service worker is tested with `npm run build && npm run preview`.
      devOptions: { enabled: false },
      // The glob below already precaches the icons; don't list them twice.
      includeManifestIcons: false,
      workbox: {
        // Precache the app shell only, so the app boots with no signal.
        globPatterns: ['**/*.{html,js,css,svg,png,ico,woff2}'],
        // Deep links load offline: navigations fall back to the cached shell.
        navigateFallback: 'index.html',
        cleanupOutdatedCaches: true,
        // No `runtimeCaching`, on purpose. The service worker must never cache
        // API or auth responses: offline data is TanStack Query + Dexie.
      },
      manifest: {
        name: 'FitnessApp',
        short_name: 'FitnessApp',
        lang: 'es',
        display: 'standalone',
        start_url: '/',
        scope: '/',
        // --background of the shadcn theme (src/index.css), as hex. Keep in
        // sync with the theme-color meta tag in index.html.
        theme_color: '#ffffff',
        background_color: '#ffffff',
        // Generated from public/logo.svg (see pwa-assets.config.mjs).
        icons: [
          { src: 'pwa-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: 'pwa-512x512.png', sizes: '512x512', type: 'image/png' },
          {
            src: 'maskable-icon-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
        ],
      },
    }),
  ],
  resolve: {
    // Keep in sync with "paths" in tsconfig.json and tsconfig.app.json.
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  test: {
    environment: 'node',
    include: ['src/**/*.test.{ts,tsx}'],
  },
})
