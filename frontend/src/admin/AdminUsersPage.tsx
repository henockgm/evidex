import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useState, type FormEvent, type ReactNode } from 'react'
import { Link, useSearchParams } from 'react-router'
import { api, unwrap, type AdminUser } from '../api/client'
import { Alert, Button, Spinner } from '../components/ui'
import { AdminUserActions } from './AdminUserActions'

const date = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' })
const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })
const providerLabels: Record<string, string> = { google_oauth2: 'Google', entra_id: 'Microsoft' }

function signInMethods(user: AdminUser) {
  return [...(user.has_password ? ['Password'] : []), ...user.providers.map((provider) => providerLabels[provider] ?? provider)]
}

function Badge({ tone = 'slate', children }: { tone?: 'slate' | 'indigo' | 'amber' | 'rose'; children: ReactNode }) {
  const tones = {
    slate: 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300',
    indigo: 'bg-indigo-50 text-indigo-700 dark:bg-indigo-950 dark:text-indigo-300',
    amber: 'bg-amber-50 text-amber-800 dark:bg-amber-950 dark:text-amber-300',
    rose: 'bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300',
  }
  return <span className={`rounded px-1.5 py-0.5 text-xs font-medium ${tones[tone]}`}>{children}</span>
}

export function AdminUsersPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const page = Math.max(Number(searchParams.get('page')) || 1, 1)
  const q = searchParams.get('q') ?? ''
  const [search, setSearch] = useState(q)

  const { data, isPending, isFetching, error } = useQuery({
    queryKey: ['admin', 'users', q, page],
    queryFn: () => unwrap(api.GET('/api/v1/admin/users', { params: { query: { q: q || undefined, page } } })),
    placeholderData: keepPreviousData,
  })

  function handleSearch(event: FormEvent) {
    event.preventDefault()
    setSearchParams(search.trim() ? { q: search.trim() } : {})
  }

  function goTo(nextPage: number) {
    setSearchParams({ ...(q ? { q } : {}), ...(nextPage > 1 ? { page: String(nextPage) } : {}) })
  }

  return (
    <div className="space-y-4">
      <form role="search" onSubmit={handleSearch} className="flex gap-2">
        <input
          type="search"
          aria-label="Search by email or name"
          placeholder="Search by email or name"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          className="block w-full rounded-md border-0 bg-white px-3 py-2 text-sm ring-1 ring-inset ring-slate-300 placeholder:text-slate-400 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700"
        />
        <Button type="submit" variant="secondary">
          Search
        </Button>
      </form>

      {isPending && <Spinner />}
      {error && <Alert tone="error">{error.message}</Alert>}

      {data && (
        <ul
          aria-busy={isFetching}
          className="divide-y divide-slate-200 overflow-hidden rounded-lg bg-white shadow-sm ring-1 ring-slate-200 dark:divide-slate-800 dark:bg-slate-900 dark:ring-slate-800"
        >
          {data.users.map((user) => (
            <li key={user.id} className="space-y-1 px-5 py-3 text-sm">
              <div className="flex flex-wrap items-center gap-2">
                <span className="font-medium">{user.email_address}</span>
                {user.name && <span className="text-slate-500">{user.name}</span>}
                <Link to={`/admin/activity?user_id=${user.id}`} className="text-indigo-600 hover:underline dark:text-indigo-400">
                  Activity
                </Link>
                {user.admin && <Badge tone="indigo">Admin</Badge>}
                {user.two_factor_enabled && <Badge>2FA</Badge>}
                {!user.email_verified && <Badge tone="amber">Unverified</Badge>}
                {user.suspended_at && <Badge tone="rose">Locked by an admin</Badge>}
                {user.locked_until && <Badge tone="rose">Locked until {dateTime.format(new Date(user.locked_until))}</Badge>}
              </div>
              <p className="text-slate-600 dark:text-slate-400">
                {[
                  `Signs in with ${signInMethods(user).join(', ') || 'nothing'}`,
                  `${user.active_sessions} active session${user.active_sessions === 1 ? '' : 's'}`,
                  user.last_active_at ? `last active ${dateTime.format(new Date(user.last_active_at))}` : 'never active',
                  `${user.ai_calls_last_30_days} AI calls in 30 days`,
                  `joined ${date.format(new Date(user.created_at))}`,
                ].join(' · ')}
              </p>
              <AdminUserActions user={user} />
            </li>
          ))}
          {data.users.length === 0 && <li className="px-5 py-6 text-center text-sm text-slate-500">No accounts found.</li>}
        </ul>
      )}

      {data && data.meta.total_pages > 1 && (
        <nav aria-label="Pages" className="flex items-center justify-between gap-4 text-sm">
          <p className="text-slate-500">
            Page {data.meta.page} of {data.meta.total_pages} · {data.meta.total} accounts
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" disabled={page <= 1} onClick={() => goTo(page - 1)}>
              Previous
            </Button>
            <Button variant="secondary" disabled={page >= data.meta.total_pages} onClick={() => goTo(page + 1)}>
              Next
            </Button>
          </div>
        </nav>
      )}
    </div>
  )
}
