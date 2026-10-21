import { useMutation, useQuery } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { Link } from 'react-router'
import { api, unwrap, type ApplicationStatus } from '../api/client'
import { StatusBadge } from '../applications/StatusBadge'
import { statusLabels } from '../applications/labels'
import { useMe } from '../auth/useAuth'
import { Alert, Button, Card, Spinner } from '../components/ui'
import { formatDate } from '../postings/labels'

const statuses = Object.keys(statusLabels) as ApplicationStatus[]
const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })
const interviewTime = new Intl.DateTimeFormat(undefined, { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })

export function DashboardPage() {
  const { data: user } = useMe()
  const resend = useMutation({ mutationFn: () => unwrap(api.POST('/api/v1/email_verification/resend')) })
  const { data: dashboard, isPending, error } = useQuery({
    queryKey: ['dashboard'],
    queryFn: () => unwrap(api.GET('/api/v1/dashboard')),
  })

  if (!user) return null

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h1 className="text-2xl font-bold tracking-tight">Welcome{user.name ? `, ${user.name}` : ''}</h1>
        <Link
          to="/postings/new"
          className="rounded-md bg-indigo-600 px-3.5 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
        >
          Add posting
        </Link>
      </div>

      {!user.email_verified && (
        <Alert tone="info">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <span>Confirm {user.email_address} to unlock the AI features.</span>
            {resend.isSuccess ? (
              <span className="font-medium">{resend.data.message}</span>
            ) : (
              <Button variant="secondary" onClick={() => resend.mutate()} disabled={resend.isPending}>
                Resend email
              </Button>
            )}
          </div>
          {resend.isError && <p className="mt-2">{resend.error.message}</p>}
        </Alert>
      )}

      {isPending && <Spinner />}
      {error && <Alert tone="error">{error.message}</Alert>}

      {dashboard && dashboard.total === 0 && (
        <Card title="Get started" description="Save the first job you're interested in. Paste its text or a link to the ad.">
          <Link to="/postings/new" className="text-sm font-semibold text-indigo-600 hover:underline dark:text-indigo-400">
            Add your first posting →
          </Link>
        </Card>
      )}

      {dashboard && dashboard.total > 0 && (
        <>
          <section aria-labelledby="pipeline-title">
            <div className="mb-3 flex items-baseline justify-between gap-4">
              <h2 id="pipeline-title" className="text-base font-semibold">
                Pipeline
              </h2>
              <Link to="/postings" className="text-sm text-indigo-600 hover:underline dark:text-indigo-400">
                All postings ({dashboard.total}) →
              </Link>
            </div>
            <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-5 lg:grid-cols-9">
              {statuses.map((status) => (
                <li key={status}>
                  <Link
                    to={`/postings?status=${status}`}
                    aria-label={`${statusLabels[status]}: ${dashboard.status_counts[status]}`}
                    className="flex h-full flex-col items-start gap-2 rounded-lg bg-white p-3 shadow-sm ring-1 ring-slate-200 hover:ring-indigo-400 dark:bg-slate-900 dark:ring-slate-800 dark:hover:ring-indigo-500"
                  >
                    <StatusBadge status={status} />
                    <span className="text-2xl font-semibold tabular-nums">{dashboard.status_counts[status]}</span>
                  </Link>
                </li>
              ))}
            </ul>
          </section>

          <Card title="Upcoming interviews" description="Scheduled in the next 14 days.">
            <BriefList
              empty="No interviews in the next two weeks."
              items={dashboard.upcoming_interviews.map((item) => ({
                key: item.interview_id,
                postingId: item.job_posting_id,
                title: item.title,
                company: [item.company, item.round].filter(Boolean).join(' · '),
                aside: interviewTime.format(new Date(item.scheduled_at)),
              }))}
            />
          </Card>

          <div className="grid gap-6 lg:grid-cols-2">
            <Card title="Upcoming deadlines" description="Postings you haven't applied to yet, due in the next 14 days.">
              <BriefList
                empty="Nothing due in the next two weeks."
                items={dashboard.upcoming_deadlines.map((item) => ({
                  key: item.job_posting_id,
                  postingId: item.job_posting_id,
                  title: item.title,
                  company: item.company,
                  aside: formatDate(item.deadline),
                }))}
              />
            </Card>

            <Card title="Next actions" description="Due in the next 7 days, including anything overdue.">
              <BriefList
                empty="No next actions due this week."
                items={dashboard.next_actions.map((item) => ({
                  key: item.job_posting_id,
                  postingId: item.job_posting_id,
                  title: item.next_action ?? 'Follow up',
                  company: `${item.title} · ${item.company}`,
                  aside: item.overdue ? (
                    <span className="font-semibold text-rose-700 dark:text-rose-300">Overdue · {formatDate(item.next_action_on)}</span>
                  ) : (
                    formatDate(item.next_action_on)
                  ),
                }))}
              />
            </Card>
          </div>

          <Card title="Recent activity">
            <BriefList
              empty="No activity yet."
              items={dashboard.recent_activity.map((item, index) => ({
                key: `${item.job_posting_id}-${index}`,
                postingId: item.job_posting_id,
                title: item.title,
                company: item.company,
                aside: (
                  <span className="flex items-center gap-2">
                    {item.from_status ? <StatusBadge status={item.to_status} /> : <span>Saved</span>}
                    <span>{dateTime.format(new Date(item.created_at))}</span>
                  </span>
                ),
              }))}
            />
          </Card>
        </>
      )}
    </div>
  )
}

interface BriefItem {
  key: string | number
  postingId: number
  title: string
  company: string
  aside: ReactNode
}

function BriefList({ items, empty }: { items: BriefItem[]; empty: string }) {
  if (!items.length) return <p className="text-sm text-slate-500">{empty}</p>

  return (
    <ul className="-mx-2 divide-y divide-slate-100 dark:divide-slate-800">
      {items.map((item) => (
        <li key={item.key}>
          <Link
            to={`/postings/${item.postingId}`}
            className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 rounded px-2 py-2 text-sm hover:bg-slate-50 dark:hover:bg-slate-800/50"
          >
            <span>
              <span className="font-medium">{item.title}</span>
              <span className="text-slate-500"> · {item.company}</span>
            </span>
            <span className="text-slate-600 dark:text-slate-400">{item.aside}</span>
          </Link>
        </li>
      ))}
    </ul>
  )
}
