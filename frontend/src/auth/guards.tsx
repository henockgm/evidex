import { Navigate, Outlet, useLocation, useSearchParams } from 'react-router'
import { safeNext } from './safeNext'
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
  const [searchParams] = useSearchParams()

  if (isPending) return <Spinner />
  // Signed in (e.g. just now on the sign-in page): go where the user was heading.
  if (user) return <Navigate to={safeNext(searchParams.get('next'))} replace />
  return <Outlet />
}
