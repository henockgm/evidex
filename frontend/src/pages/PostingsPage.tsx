import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router'
import { api, unwrap } from '../api/client'
import { Alert, Spinner } from '../components/ui'
import { formatDate, workModelLabels } from '../postings/labels'
import { postingsQueryKey } from '../postings/queries'
import { StatusBadge } from '../applications/StatusBadge'

export function PostingsPage() {
  const { data: postings, isPending, error } = useQuery({
    queryKey: postingsQueryKey,
    queryFn: async () => (await unwrap(api.GET('/api/v1/job_postings'))).job_postings,
  })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-2xl font-bold tracking-tight">Job postings</h1>
        <Link
          to="/postings/new"
          className="rounded-md bg-indigo-600 px-3.5 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
        >
          Add posting
        </Link>
      </div>

      {isPending && <Spinner />}
      {error && <Alert tone="error">{error.message}</Alert>}
      {postings?.length === 0 && (
        <div className="rounded-lg border border-dashed border-slate-300 p-10 text-center text-sm text-slate-500 dark:border-slate-700">
          No postings yet. Add one by pasting the job ad's text.
        </div>
      )}

      {postings && postings.length > 0 && (
        <ul className="divide-y divide-slate-200 overflow-hidden rounded-lg bg-white shadow-sm ring-1 ring-slate-200 dark:divide-slate-800 dark:bg-slate-900 dark:ring-slate-800">
          {postings.map((posting) => (
            <li key={posting.id}>
              <Link to={`/postings/${posting.id}`} className="block px-5 py-4 hover:bg-slate-50 dark:hover:bg-slate-800/50">
                <div className="flex items-center justify-between gap-3">
                  <p className="font-medium">{posting.title}</p>
                  <StatusBadge status={posting.status} />
                </div>
                <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
                  {[posting.company, posting.location, posting.work_model && workModelLabels[posting.work_model]]
                    .filter(Boolean)
                    .join(' · ')}
                  {posting.deadline && <> · Deadline {formatDate(posting.deadline)}</>}
                </p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
