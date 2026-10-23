import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Link, useSearchParams } from 'react-router'
import { api, unwrap } from '../api/client'
import { Alert, Spinner } from '../components/ui'

const periods = [7, 30, 90] as const
const usd = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2, maximumFractionDigits: 4 })
const count = new Intl.NumberFormat()

/** AI calls, tokens and estimated cost per account. */
export function AdminAiUsagePage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const days = periods.find((period) => String(period) === searchParams.get('days')) ?? 30

  const { data, isPending, isFetching, error } = useQuery({
    queryKey: ['admin', 'ai_usage', days],
    queryFn: () => unwrap(api.GET('/api/v1/admin/ai_usage', { params: { query: { days } } })),
    placeholderData: keepPreviousData,
  })

  return (
    <div className="space-y-4">
      <div role="group" aria-label="Period" className="inline-flex overflow-hidden rounded-md ring-1 ring-slate-300 dark:ring-slate-700">
        {periods.map((period) => (
          <button
            key={period}
            type="button"
            aria-pressed={period === days}
            onClick={() => setSearchParams(period === 30 ? {} : { days: String(period) })}
            className={`px-3 py-1.5 text-sm ${period === days ? 'bg-indigo-600 font-semibold text-white' : 'bg-white hover:bg-slate-50 dark:bg-slate-900 dark:hover:bg-slate-800'}`}
          >
            {period} days
          </button>
        ))}
      </div>

      {isPending && <Spinner />}
      {error && <Alert tone="error">{error.message}</Alert>}

      {data && (
        <div aria-busy={isFetching} className="space-y-4">
          <p className="text-sm text-slate-600 dark:text-slate-400">
            {count.format(data.totals.calls)} calls ({count.format(data.totals.failed_calls)} failed) ·{' '}
            {count.format(data.totals.input_tokens)} input and {count.format(data.totals.output_tokens)} output tokens · about{' '}
            <span className="font-semibold text-slate-900 dark:text-slate-100">{usd.format(data.totals.estimated_cost_usd)}</span> at list
            prices
          </p>
          {data.totals.unpriced_models.length > 0 && (
            <Alert tone="info">No price known for {data.totals.unpriced_models.join(', ')}; those calls aren't in the estimate.</Alert>
          )}

          <div className="overflow-x-auto rounded-lg bg-white shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
            <table className="min-w-full text-sm">
              <thead className="text-left text-slate-600 dark:text-slate-400">
                <tr>
                  <th className="px-4 py-2 font-medium">Account</th>
                  <th className="px-4 py-2 text-right font-medium">Calls</th>
                  <th className="px-4 py-2 text-right font-medium">Input tokens</th>
                  <th className="px-4 py-2 text-right font-medium">Output tokens</th>
                  <th className="px-4 py-2 text-right font-medium">Est. cost</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
                {data.users.map((row) => (
                  <tr key={row.user.id}>
                    <td className="px-4 py-2">
                      <Link to={`/admin/activity?user_id=${row.user.id}`} className="hover:underline">
                        {row.user.email_address}
                      </Link>
                      <span className="block text-xs text-slate-500">{row.models.join(', ')}</span>
                    </td>
                    <td className="px-4 py-2 text-right tabular-nums">
                      {count.format(row.calls)}
                      {row.failed_calls > 0 && <span className="text-rose-700 dark:text-rose-300"> ({row.failed_calls} failed)</span>}
                    </td>
                    <td className="px-4 py-2 text-right tabular-nums">{count.format(row.input_tokens)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">{count.format(row.output_tokens)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">{usd.format(row.estimated_cost_usd)}</td>
                  </tr>
                ))}
                {data.users.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-6 text-center text-slate-500">
                      No AI calls in the last {days} days.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
