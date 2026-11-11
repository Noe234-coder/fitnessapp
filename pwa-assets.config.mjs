// Config for the one-off icon generation (the generator is not a dependency):
//
//   npx @vite-pwa/assets-generator
//
// It writes the PNG icons next to public/logo.svg. They are committed; run it
// again only when the logo changes.

// The logo's own background, so the padded icons have no visible edge.
const background = '#171717'

const prefixes = { transparent: 'pwa', maskable: 'maskable-icon' }

export default {
  preset: {
    transparent: { sizes: [192, 512], favicons: [], padding: 0 },
    maskable: { sizes: [512], padding: 0.15, resizeOptions: { background } },
    apple: { sizes: [180], padding: 0.1, resizeOptions: { background } },
    // The generator's default names, except for the single Apple icon:
    // `apple-touch-icon.png` is the name iOS looks for at the site root.
    assetName: (type, size) =>
      type === 'apple'
        ? 'apple-touch-icon.png'
        : `${prefixes[type]}-${size.width}x${size.height}.png`,
  },
  images: ['public/logo.svg'],
}
