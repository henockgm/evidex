import { useQuery } from '@tanstack/react-query'
import { api, unwrap } from '../api/client'
import { Alert, Spinner } from '../components/ui'

export function AdminOverviewPage() {
  const { data, isPending, error } = useQuery({
    queryKey: ['admin', 'overview'],
    queryFn: () => unwrap(api.GET('/api/v1/admin/overview')),
  })

  if (isPending) return <Spinner />
  if (error) return <Alert tone="error">{error.message}</Alert>

  const stats = [
    { label: 'Users', value: data.users },
    { label: 'Verified email', value: data.verified_users },
    { label: 'Two-factor on', value: data.two_factor_users },
    { label: 'Active sessions', value: data.active_sessions },
    { label: 'AI calls, last 30 days', value: data.ai_calls_last_30_days },
  ]

  return (
    <dl className="grid grid-cols-2 gap-4 sm:grid-cols-3">
      {stats.map((stat) => (
        <div key={stat.label} className="rounded-lg bg-white p-4 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
          <dt className="text-sm text-slate-600 dark:text-slate-400">{stat.label}</dt>
          <dd className="mt-1 text-2xl font-semibold tabular-nums">{stat.value}</dd>
        </div>
      ))}
    </dl>
  )
}
