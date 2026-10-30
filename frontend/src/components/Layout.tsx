import { Link, NavLink, Outlet } from 'react-router'
import { leaveApp, signOut, useMe } from '../auth/useAuth'
import { CONTACT_EMAIL, SOURCE_URL } from '../site'
import { DemoBanner } from './DemoBanner'

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
    <div className="flex min-h-screen flex-col bg-slate-50 dark:bg-slate-950">
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
              {!user.demo && (
                <NavLink to="/settings/security" className="hover:underline">
                  Security
                </NavLink>
              )}
              {user.admin && (
                <NavLink to="/admin" className="hover:underline">
                  Admin
                </NavLink>
              )}
              <button type="button" onClick={handleSignOut} className="font-medium hover:underline">
                Sign out
              </button>
            </div>
          )}
        </nav>
      </header>
      {user?.demo && <DemoBanner />}
      <main className="mx-auto w-full max-w-4xl flex-1 px-4 py-10">
        <Outlet />
      </main>
      <footer className="border-t border-slate-200 dark:border-slate-800">
        <div className="mx-auto flex max-w-4xl flex-wrap items-center gap-x-4 gap-y-1 px-4 py-4 text-sm text-slate-600 dark:text-slate-400">
          <span>© {new Date().getFullYear()} Henock Mullissa</span>
          <Link to="/privacy" className="hover:underline">
            Privacy
          </Link>
          <a href={SOURCE_URL} target="_blank" rel="noreferrer" className="hover:underline">
            Source on GitHub
          </a>
          <a href={`mailto:${CONTACT_EMAIL}`} className="hover:underline">
            Contact
          </a>
        </div>
      </footer>
    </div>
  )
}
