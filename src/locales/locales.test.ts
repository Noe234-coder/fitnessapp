import { describe, expect, it } from 'vitest'

import en from './en/common.json'
import es from './es/common.json'

type TranslationTree = { [key: string]: string | TranslationTree }

/** Flattens nested translations into sorted dotted keys: 'home.tagline'. */
function flattenKeys(tree: TranslationTree, prefix = ''): string[] {
  return Object.entries(tree)
    .flatMap(([key, value]) =>
      typeof value === 'string'
        ? [`${prefix}${key}`]
        : flattenKeys(value, `${prefix}${key}.`),
    )
    .sort()
}

describe('locales', () => {
  it('es and en have exactly the same keys', () => {
    expect(flattenKeys(en)).toEqual(flattenKeys(es))
  })

  it('no translation is empty', () => {
    for (const [language, tree] of Object.entries({ es, en })) {
      const empty = flattenKeys(tree).filter((key) => {
        const value = key
          .split('.')
          .reduce<string | TranslationTree | undefined>(
            (node, part) => (typeof node === 'object' ? node[part] : undefined),
            tree,
          )
        return typeof value !== 'string' || value.trim() === ''
      })
      expect(empty, `empty keys in ${language}`).toEqual([])
    }
  })
})
