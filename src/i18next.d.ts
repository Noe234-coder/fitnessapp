import 'i18next'

import type { defaultNS, Translations } from '@/lib/i18n'

// Makes `t('some.key')` type-checked: an unknown key is a type error.
declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: typeof defaultNS
    resources: {
      common: Translations
    }
  }
}
