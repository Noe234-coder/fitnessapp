import { Outlet } from 'react-router'

/** Mobile-first shell: one centred column that respects the safe areas. */
export function RootLayout() {
  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-4 pt-[env(safe-area-inset-top)] pb-[env(safe-area-inset-bottom)]">
      <Outlet />
    </div>
  )
}
