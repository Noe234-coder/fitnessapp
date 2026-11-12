/** The part of the Web Storage API the app uses; tests pass a fake. */
export type KeyValueStorage = Pick<
  Storage,
  'getItem' | 'setItem' | 'removeItem'
>

/**
 * localStorage that never throws: private windows and blocked site data can
 * make every access fail, and the app must still render.
 */
export const safeLocalStorage: KeyValueStorage = {
  getItem(key) {
    try {
      return window.localStorage.getItem(key)
    } catch {
      return null
    }
  },
  setItem(key, value) {
    try {
      window.localStorage.setItem(key, value)
    } catch {
      // Nothing to do: the value is simply not remembered.
    }
  },
  removeItem(key) {
    try {
      window.localStorage.removeItem(key)
    } catch {
      // Same as above.
    }
  },
}

/** JSON.parse that returns undefined instead of throwing. */
export function parseJson(raw: string | null): unknown {
  if (raw === null) return undefined
  try {
    return JSON.parse(raw) as unknown
  } catch {
    return undefined
  }
}
