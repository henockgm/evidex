import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Link, useSearchParams } from 'react-router'
import { api, unwrap } from '../api/client'
import { Alert, Button, Spinner } from '../components/ui'
import { activityDetail, activityLabels, warningActions } from '../security/activityLabels'

const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })

export function ActivityPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const page = Math.max(Number(searchParams.get('page')) || 1, 1)

  const { data, isPending, isFetching, error } = useQuery({
    queryKey: ['me', 'activity', page],
    queryFn: () => unwrap(api.GET('/api/v1/me/activity', { params: { query: { page } } })),
    placeholderData: keepPreviousData,
  })

  return (
    <div className="space-y-6">
      <div>
        <Link to="/settings/security" className="text-sm text-indigo-600 hover:underline dark:text-indigo-400">
          ← Security
        </Link>
        <h1 className="mt-2 text-2xl font-bold tracking-tight">Security activity</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Sign-ins and changes to your account. If something here wasn't you, change your password and sign out the devices you
          don't recognise.
        </p>
      </div>

      {isPending && <Spinner />}
      {error && <Alert tone="error">{error.message}</Alert>}

      {data && (
        <ul
          aria-busy={isFetching}
          className="divide-y divide-slate-200 overflow-hidden rounded-lg bg-white shadow-sm ring-1 ring-slate-200 dark:divide-slate-800 dark:bg-slate-900 dark:ring-slate-800"
        >
          {data.events.map((event) => {
            const detail = activityDetail(event)
            const warning = warningActions.has(event.action)
            return (
              <li key={event.id} className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 px-5 py-3 text-sm">
                <div>
                  <p className={`font-medium ${warning ? 'text-rose-700 dark:text-rose-300' : ''}`}>
                    {activityLabels[event.action]}
                    {detail && <span className="font-normal text-slate-600 dark:text-slate-400"> {detail}</span>}
                  </p>
                  <p className="text-slate-500">{[event.device, event.ip_address].filter(Boolean).join(' · ') || 'Unknown device'}</p>
                </div>
                <time dateTime={event.created_at} className="text-slate-600 dark:text-slate-400">
                  {dateTime.format(new Date(event.created_at))}
                </time>
              </li>
            )
          })}
          {data.events.length === 0 && <li className="px-5 py-6 text-center text-sm text-slate-500">No activity yet.</li>}
        </ul>
      )}

      {data && data.meta.total_pages > 1 && (
        <nav aria-label="Pages" className="flex items-center justify-between gap-4 text-sm">
          <p className="text-slate-500">
            Page {data.meta.page} of {data.meta.total_pages}
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" disabled={page <= 1} onClick={() => setSearchParams(page === 2 ? {} : { page: String(page - 1) })}>
              Newer
            </Button>
            <Button
              variant="secondary"
              disabled={page >= data.meta.total_pages}
              onClick={() => setSearchParams({ page: String(page + 1) })}
            >
              Older
            </Button>
          </div>
        </nav>
      )}
    </div>
  )
}
