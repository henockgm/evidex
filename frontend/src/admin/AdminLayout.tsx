import { Link, NavLink, Navigate, Outlet } from 'react-router'
import { useMe } from '../auth/useAuth'
import { Alert, Spinner } from '../components/ui'

const tabs = [
  { to: '/admin', label: 'Overview', end: true },
  { to: '/admin/users', label: 'Users', end: false },
]

/** The admin area: admins only, and only with two-factor sign-in on (the API enforces both). */
export function AdminLayout() {
  const { data: user, isPending } = useMe()

  if (isPending) return <Spinner />
  if (!user?.admin) return <Navigate to="/" replace />

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Admin</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Accounts, security activity and AI usage. Users' documents, postings and letters are never shown here.
        </p>
      </div>

      {user.two_factor_enabled ? (
        <>
          <nav aria-label="Admin" className="flex gap-4 border-b border-slate-200 text-sm dark:border-slate-800">
            {tabs.map((tab) => (
              <NavLink
                key={tab.to}
                to={tab.to}
                end={tab.end}
                className={({ isActive }) =>
                  `-mb-px border-b-2 px-1 pb-2 ${isActive ? 'border-indigo-600 font-semibold text-indigo-700 dark:text-indigo-300' : 'border-transparent text-slate-600 hover:text-slate-900 dark:text-slate-400'}`
                }
              >
                {tab.label}
              </NavLink>
            ))}
          </nav>
          <Outlet />
        </>
      ) : (
        <Alert tone="info">
          Turn on two-factor sign-in to use the admin area.{' '}
          <Link to="/settings/security" className="font-medium underline">
            Security settings
          </Link>
        </Alert>
      )}
    </div>
  )
}
