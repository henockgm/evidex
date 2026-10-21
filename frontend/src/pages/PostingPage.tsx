import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router'
import { api, unwrap } from '../api/client'
import { Alert, Button, Card, Spinner } from '../components/ui'
import { formatDate, workModelLabels } from '../postings/labels'
import { postingListsQueryKey, postingQueryKey } from '../postings/queries'
import { RequirementsCard } from '../postings/RequirementsCard'
import { AiExtractionCard } from '../postings/AiExtractionCard'
import { ApplicationCard } from '../applications/ApplicationCard'
import { ApplicationDetailsCard } from '../applications/ApplicationDetailsCard'
import { ContactsCard } from '../applications/ContactsCard'
import { InterviewsCard } from '../applications/InterviewsCard'
import { StatusBadge } from '../applications/StatusBadge'
import { usePosting } from '../postings/usePosting'

export function PostingPage() {
  const id = Number(useParams().id)
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { data: posting, isPending, error } = usePosting(id)
  const [confirmingDelete, setConfirmingDelete] = useState(false)

  const destroy = useMutation({
    mutationFn: () => unwrap(api.DELETE('/api/v1/job_postings/{id}', { params: { path: { id } } })),
    onSuccess: () => {
      queryClient.removeQueries({ queryKey: postingQueryKey(id) })
      void queryClient.invalidateQueries({ queryKey: postingListsQueryKey })
      navigate('/postings')
    },
  })

  if (isPending) return <Spinner />
  if (error || !posting) return <Alert tone="error">{error?.message ?? 'Posting not found.'}</Alert>

  const details = [
    ['Company', posting.company],
    ['Location', posting.location],
    ['Work model', posting.work_model && workModelLabels[posting.work_model]],
    ['Employment type', posting.employment_type],
    ['Seniority', posting.seniority],
    ['Salary', posting.salary],
    ['Deadline', posting.deadline && formatDate(posting.deadline)],
  ].filter((pair): pair is [string, string] => Boolean(pair[1]))

  return (
    <div className="space-y-6">
      <div>
        <Link to="/postings" className="text-sm text-indigo-600 hover:underline dark:text-indigo-400">
          ← All postings
        </Link>
        <div className="mt-2 flex flex-wrap items-start justify-between gap-4">
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="text-2xl font-bold tracking-tight">{posting.title}</h1>
            <StatusBadge status={posting.status} />
          </div>
          <div className="flex gap-3">
            <Link
              to={`/postings/${id}/edit`}
              className="rounded-md bg-white px-3.5 py-2 text-sm font-semibold shadow-sm ring-1 ring-inset ring-slate-300 hover:bg-slate-50 dark:bg-slate-900 dark:ring-slate-700 dark:hover:bg-slate-800"
            >
              Edit
            </Link>
            {!confirmingDelete && (
              <Button variant="secondary" onClick={() => setConfirmingDelete(true)}>
                Delete
              </Button>
            )}
          </div>
        </div>
      </div>

      {confirmingDelete && (
        <Alert tone="error">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <span>Delete this posting? This can't be undone.</span>
            <div className="flex gap-2">
              <Button variant="secondary" onClick={() => setConfirmingDelete(false)} disabled={destroy.isPending}>
                Cancel
              </Button>
              <Button variant="danger" onClick={() => destroy.mutate()} disabled={destroy.isPending}>
                {destroy.isPending ? 'Deleting…' : 'Delete posting'}
              </Button>
            </div>
          </div>
          {destroy.isError && <p className="mt-2">{destroy.error.message}</p>}
        </Alert>
      )}

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
        {posting.keywords.length > 0 && (
          <ul aria-label="Keywords" className="mt-4 flex flex-wrap gap-2">
            {posting.keywords.map((keyword) => (
              <li
                key={keyword}
                className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-700 dark:bg-slate-800 dark:text-slate-200"
              >
                {keyword}
              </li>
            ))}
          </ul>
        )}
      </Card>

      <ApplicationCard postingId={posting.id} application={posting.application} />

      <InterviewsCard postingId={posting.id} applicationId={posting.application.id} interviews={posting.application.interviews} />

      <ApplicationDetailsCard postingId={posting.id} application={posting.application} />

      <ContactsCard postingId={posting.id} applicationId={posting.application.id} contacts={posting.application.contacts} />

      <AiExtractionCard posting={posting} />

      <RequirementsCard postingId={posting.id} requirements={posting.requirements} />

      <Card title="Job ad text">
        <div className="whitespace-pre-wrap text-sm leading-6">{posting.description}</div>
      </Card>
    </div>
  )
}
