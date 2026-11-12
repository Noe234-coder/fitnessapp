import { EyeIcon, EyeOffIcon } from 'lucide-react'
import { useId, useState, type ComponentProps, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

type TextFieldProps = Omit<ComponentProps<'input'>, 'id'> & {
  label: string
  /** Already translated; shown under the field and announced. */
  error?: string | null
  /** Rendered over the right edge of the input (the password toggle). */
  trailing?: ReactNode
}

/** A labelled input. 16px text, so iOS does not zoom in on focus. */
export function TextField({
  label,
  error,
  trailing,
  className,
  ...props
}: TextFieldProps) {
  const id = useId()
  const errorId = `${id}-error`

  return (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-sm font-medium">
        {label}
      </label>
      <div className="relative">
        <input
          id={id}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? errorId : undefined}
          className={cn(
            'h-11 w-full rounded-lg border border-input bg-background px-3 text-base outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 read-only:bg-muted',
            trailing ? 'pr-12' : null,
            className,
          )}
          {...props}
        />
        {trailing}
      </div>
      {error ? (
        <p id={errorId} role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  )
}

/** A password input with a show/hide toggle. */
export function PasswordField(
  props: Omit<TextFieldProps, 'type' | 'trailing'>,
) {
  const { t } = useTranslation()
  const [visible, setVisible] = useState(false)

  return (
    <TextField
      {...props}
      type={visible ? 'text' : 'password'}
      trailing={
        <button
          type="button"
          aria-label={t(visible ? 'auth.password.hide' : 'auth.password.show')}
          aria-pressed={visible}
          className="absolute inset-y-0 right-0 flex w-11 items-center justify-center rounded-r-lg text-muted-foreground outline-none hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50"
          onClick={() => setVisible((value) => !value)}
        >
          {visible ? (
            <EyeOffIcon className="size-5" aria-hidden />
          ) : (
            <EyeIcon className="size-5" aria-hidden />
          )}
        </button>
      }
    />
  )
}

/** A form-level error message. */
export function FormError({ children }: { children: ReactNode }) {
  return (
    <p
      role="alert"
      className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive"
    >
      {children}
    </p>
  )
}
