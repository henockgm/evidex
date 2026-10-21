import { Link, NavLink, Outlet } from 'react-router'
import { leaveApp, signOut, useMe } from '../auth/useAuth'

export function Layout() {
  const { data: user } = useMe()

  async function handleSignOut() {
    try {
      await signOut()
    } finally {
      leaveApp('/login')
    }
  }

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950">
      <header className="border-b border-slate-200 bg-white dark:border-slate-800 dark:bg-slate-900">
        <nav className="mx-auto flex max-w-4xl items-center justify-between gap-4 px-4 py-3" aria-label="Main">
          <Link to="/" className="text-lg font-bold tracking-tight">
            Evidex
          </Link>
          {user && (
            <div className="flex items-center gap-3 whitespace-nowrap text-sm sm:gap-4">
              <NavLink to="/postings" className="hover:underline">
                Postings
              </NavLink>
              <NavLink to="/library" className="hover:underline">
                Library
              </NavLink>
              <NavLink to="/settings/security" className="hover:underline">
                Security
              </NavLink>
              <button type="button" onClick={handleSignOut} className="font-medium hover:underline">
                Sign out
              </button>
            </div>
          )}
        </nav>
      </header>
      <main className="mx-auto max-w-4xl px-4 py-10">
        <Outlet />
      </main>
    </div>
  )
}
