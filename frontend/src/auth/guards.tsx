import { Navigate, Outlet, useLocation } from 'react-router'
import { Spinner } from '../components/ui'
import { useMe } from './useAuth'

export function RequireAuth() {
  const { data: user, isPending } = useMe()
  const location = useLocation()

  if (isPending) return <Spinner />
  if (!user) return <Navigate to={`/login?next=${encodeURIComponent(location.pathname)}`} replace />
  return <Outlet />
}

export function GuestOnly() {
  const { data: user, isPending } = useMe()

  if (isPending) return <Spinner />
  if (user) return <Navigate to="/" replace />
  return <Outlet />
}
