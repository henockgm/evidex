import { useQuery } from '@tanstack/react-query'
import { Link, useParams } from 'react-router'
import { api, unwrap } from '../api/client'
import { Alert, Card, Spinner } from '../components/ui'
import { formatDate, workModelLabels } from '../postings/labels'
import { postingQueryKey } from '../postings/queries'

export function PostingPage() {
  const id = Number(useParams().id)
  const { data: posting, isPending, error } = useQuery({
    queryKey: postingQueryKey(id),
    queryFn: async () => (await unwrap(api.GET('/api/v1/job_postings/{id}', { params: { path: { id } } }))).job_posting,
  })

  if (isPending) return <Spinner />
  if (error || !posting) return <Alert tone="error">{error?.message ?? 'Posting not found.'}</Alert>

  const details = [
    ['Company', posting.company],
    ['Location', posting.location],
    ['Work model', posting.work_model && workModelLabels[posting.work_model]],
    ['Deadline', posting.deadline && formatDate(posting.deadline)],
  ].filter((pair): pair is [string, string] => Boolean(pair[1]))

  return (
    <div className="space-y-6">
      <div>
        <Link to="/postings" className="text-sm text-indigo-600 hover:underline dark:text-indigo-400">
          ← All postings
        </Link>
        <h1 className="mt-2 text-2xl font-bold tracking-tight">{posting.title}</h1>
      </div>

      <Card title="Details">
        <dl className="grid gap-x-6 gap-y-3 text-sm sm:grid-cols-2">
          {details.map(([label, value]) => (
            <div key={label}>
              <dt className="text-slate-500">{label}</dt>
              <dd className="font-medium">{value}</dd>
            </div>
          ))}
          {posting.source_url && (
            <div className="sm:col-span-2">
              <dt className="text-slate-500">Original ad</dt>
              <dd>
                <a
                  href={posting.source_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="break-all font-medium text-indigo-600 hover:underline dark:text-indigo-400"
                >
                  {posting.source_url}
                </a>
              </dd>
            </div>
          )}
        </dl>
      </Card>

      <Card title="Job ad text">
        <div className="whitespace-pre-wrap text-sm leading-6">{posting.description}</div>
      </Card>
    </div>
  )
}
