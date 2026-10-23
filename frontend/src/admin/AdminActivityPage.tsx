import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Link, useSearchParams } from 'react-router'
import { api, unwrap, type AuditEvent } from '../api/client'
import { Alert, Button, Select, Spinner } from '../components/ui'
import { activityDetail, activityLabels, warningActions } from '../security/activityLabels'

const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })
const actions = Object.keys(activityLabels) as AuditEvent['action'][]

/** Security events across all accounts, filterable by account and kind. */
export function AdminActivityPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const page = Math.max(Number(searchParams.get('page')) || 1, 1)
  const userId = Number(searchParams.get('user_id')) || undefined
  const eventAction = (searchParams.get('event_action') || undefined) as AuditEvent['action'] | undefined

  const { data, isPending, isFetching, error } = useQuery({
    queryKey: ['admin', 'audit_events', userId, eventAction, page],
    queryFn: () =>
      unwrap(api.GET('/api/v1/admin/audit_events', { params: { query: { user_id: userId, event_action: eventAction, page } } })),
    placeholderData: keepPreviousData,
  })

  function update(changes: Record<string, string | undefined>) {
    const next = new URLSearchParams(searchParams)
    next.delete('page')
    for (const [key, value] of Object.entries(changes)) {
      if (value) next.set(key, value)
      else next.delete(key)
    }
    setSearchParams(next)
  }

  const filteredEmail = userId && data?.events.find((event) => event.user?.id === userId)?.user?.email_address

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div className="w-full sm:w-72">
          <Select
            label="Kind of event"
            value={eventAction ?? ''}
            onChange={(event) => update({ event_action: event.target.value })}
            options={[{ value: '', label: 'All events' }, ...actions.map((action) => ({ value: action, label: activityLabels[action] }))]}
          />
        </div>
        {userId && (
          <p className="text-sm text-slate-600 dark:text-slate-400">
            Only {filteredEmail || `account #${userId}`} ·{' '}
            <button type="button" className="font-medium text-indigo-600 hover:underline dark:text-indigo-400" onClick={() => update({ user_id: undefined })}>
              Show all accounts
            </button>
          </p>
        )}
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
            return (
              <li key={event.id} className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 px-5 py-3 text-sm">
                <div>
                  <p className={`font-medium ${warningActions.has(event.action) ? 'text-rose-700 dark:text-rose-300' : ''}`}>
                    {activityLabels[event.action]}
                    {detail && <span className="font-normal text-slate-600 dark:text-slate-400"> {detail}</span>}
                  </p>
                  <p className="text-slate-500">
                    {event.user ? (
                      <Link to={`/admin/activity?user_id=${event.user.id}`} className="hover:underline">
                        {event.user.email_address}
                      </Link>
                    ) : (
                      'Unknown account'
                    )}
                    {event.admin_email_address && ` · by ${event.admin_email_address}`}
                    {[event.device, event.ip_address].filter(Boolean).map((part) => ` · ${part}`)}
                  </p>
                </div>
                <time dateTime={event.created_at} className="text-slate-600 dark:text-slate-400">
                  {dateTime.format(new Date(event.created_at))}
                </time>
              </li>
            )
          })}
          {data.events.length === 0 && <li className="px-5 py-6 text-center text-sm text-slate-500">No events.</li>}
        </ul>
      )}

      {data && data.meta.total_pages > 1 && (
        <nav aria-label="Pages" className="flex items-center justify-between gap-4 text-sm">
          <p className="text-slate-500">
            Page {data.meta.page} of {data.meta.total_pages}
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" disabled={page <= 1} onClick={() => update({ page: page > 2 ? String(page - 1) : undefined })}>
              Newer
            </Button>
            <Button variant="secondary" disabled={page >= data.meta.total_pages} onClick={() => update({ page: String(page + 1) })}>
              Older
            </Button>
          </div>
        </nav>
      )}
    </div>
  )
}
