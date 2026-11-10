import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'

import en from '@/locales/en/common.json'
import es from '@/locales/es/common.json'

export const supportedLanguages = ['es', 'en'] as const
export type Language = (typeof supportedLanguages)[number]

export const defaultLanguage: Language = 'es'
export const defaultNS = 'common'

/** Spanish is the source of truth for the shape of the translations. */
export type Translations = typeof es

// Typing the English file as `Translations` makes a missing English key a
// type error. (An extra English key is caught by locales.test.ts.)
const enTranslations: Translations = en

// Bundled at build time, never fetched: the app must boot offline.
export const resources = {
  es: { common: es },
  en: { common: enTranslations },
} satisfies Record<Language, { common: Translations }>

// No language detector: the language is Spanish unless switched. From step 4
// on it comes from profiles.locale.
void i18n.use(initReactI18next).init({
  resources,
  lng: defaultLanguage,
  fallbackLng: defaultLanguage,
  supportedLngs: supportedLanguages,
  defaultNS,
  interpolation: {
    // React already escapes rendered values.
    escapeValue: false,
  },
})

if (typeof document !== 'undefined') {
  i18n.on('languageChanged', (language) => {
    document.documentElement.lang = language
  })
}

export default i18n
