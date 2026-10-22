import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { ApiError, api, unwrap, type MatchReport, type RequirementMatch } from '../api/client'
import { useMe } from '../auth/useAuth'
import { Alert, Button, Card } from '../components/ui'
import { matchReportQueryKey, verdictDescriptions, verdictLabels, verdictTones, type Verdict } from './verdicts'

const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })
const kindLabels: Record<RequirementMatch['requirement_kind'], string> = {
  required: 'Required',
  preferred: 'Nice to have',
  responsibility: 'Responsibility',
}

async function fetchLatest(postingId: number): Promise<MatchReport | null> {
  const { data, error, response } = await api.GET('/api/v1/job_postings/{id}/match_report', { params: { path: { id: postingId } } })
  if (response.status === 404) return null
  if (!response.ok || !data) throw new ApiError(response.status, error)
  return data.match_report
}

export function MatchReportCard({ postingId }: { postingId: number }) {
  const { data: user } = useMe()
  const queryClient = useQueryClient()
  const { data: report, isPending } = useQuery({
    queryKey: matchReportQueryKey(postingId),
    queryFn: () => fetchLatest(postingId),
    // Poll while the report is being prepared.
    refetchInterval: (query) => (query.state.data && !['done', 'failed'].includes(query.state.data.status) ? 2000 : false),
  })

  const versionsKey = [...matchReportQueryKey(postingId), 'versions'] as const
  const { data: versions = [] } = useQuery({
    queryKey: [...versionsKey, report?.id, report?.status],
    queryFn: async () =>
      (await unwrap(api.GET('/api/v1/job_postings/{job_posting_id}/match_reports', { params: { path: { job_posting_id: postingId } } })))
        .match_reports,
    enabled: Boolean(report),
  })
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const viewingOld = selectedId !== null && selectedId !== report?.id
  const { data: oldReport } = useQuery({
    queryKey: ['match-reports', selectedId],
    queryFn: async () => (await unwrap(api.GET('/api/v1/match_reports/{id}', { params: { path: { id: selectedId! } } }))).match_report,
    enabled: viewingOld,
  })

  const run = useMutation({
    mutationFn: () =>
      unwrap(api.POST('/api/v1/job_postings/{job_posting_id}/match_reports', { params: { path: { job_posting_id: postingId } } })),
    onSuccess: ({ match_report }) => {
      setSelectedId(null)
      queryClient.setQueryData(matchReportQueryKey(postingId), match_report)
    },
  })

  if (!user?.ai_configured) return null

  const preparing = report && (report.status === 'pending' || report.status === 'running')
  const runError = run.error instanceof ApiError ? (run.error.problem?.detail ?? run.error.message) : run.error?.message

  return (
    <Card
      title="Match report"
      description="How well your career library covers this posting's requirements, with the passages that show it."
    >
      <div className="space-y-4">
        {!user.email_verified && <p className="text-sm text-slate-500">Confirm your email address to use AI features.</p>}
        {runError && <Alert tone="error">{runError}</Alert>}
        {report?.status === 'failed' && <Alert tone="error">{report.error ?? 'The report could not be prepared.'}</Alert>}

        <div className="flex flex-wrap items-center gap-3">
          <Button onClick={() => run.mutate()} disabled={!user.email_verified || Boolean(preparing) || run.isPending}>
            {preparing || run.isPending ? 'Preparing the report…' : report ? 'Run again' : 'Run match report'}
          </Button>
          {preparing && (
            <span role="status" className="text-sm text-slate-500">
              Reading your documents against each requirement. This takes up to a minute.
            </span>
          )}
          {versions.length > 1 ? (
            <label className="flex items-center gap-2 text-sm text-slate-500">
              <span>Version</span>
              <select
                value={viewingOld ? String(selectedId) : String(report?.id ?? '')}
                onChange={(event) => setSelectedId(Number(event.target.value))}
                className="rounded-md border-0 bg-white py-1 pl-2 pr-8 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700"
              >
                {versions.map((version, index) => (
                  <option key={version.id} value={version.id}>
                    {`v${version.version}${index === 0 ? ' (latest)' : ''} · ${
                      version.status === 'done'
                        ? `${version.counts.evidenced} evidenced, ${version.counts.transferable} transferable, ${version.counts.gap} gaps`
                        : version.status
                    } · ${dateTime.format(new Date(version.completed_at ?? version.created_at))}`}
                  </option>
                ))}
              </select>
            </label>
          ) : (
            report?.status === 'done' &&
            report.completed_at && (
              <span className="text-sm text-slate-500">
                Version {report.version} · {dateTime.format(new Date(report.completed_at))}
              </span>
            )
          )}
        </div>

        {!isPending && !report && !run.isPending && (
          <p className="text-sm text-slate-500">
            No report yet. It needs requirements on this posting and at least one document in your library.
          </p>
        )}

        {viewingOld ? (
          oldReport && (
            <>
              <Alert tone="info">
                You're looking at version {oldReport.version}. Older versions are read-only; change verdicts on the latest one.
              </Alert>
              {oldReport.status === 'done' && <ReportBody report={oldReport} postingId={postingId} readOnly />}
            </>
          )
        ) : (
          report?.status === 'done' && <ReportBody report={report} postingId={postingId} />
        )}
      </div>
    </Card>
  )
}

function ReportBody({ report, postingId, readOnly = false }: { report: MatchReport; postingId: number; readOnly?: boolean }) {
  return (
    <div className="space-y-5">
      <ul aria-label="Summary" className="grid grid-cols-3 gap-3">
        {(Object.keys(verdictLabels) as Verdict[]).map((verdict) => (
          <li key={verdict} className="rounded-lg p-3 ring-1 ring-slate-200 dark:ring-slate-800">
            <VerdictBadge verdict={verdict} />
            <p className="mt-2 text-2xl font-semibold tabular-nums">{report.counts[verdict]}</p>
          </li>
        ))}
      </ul>

      {(report.strengths.length > 0 || report.gaps.length > 0) && (
        <div className="grid gap-4 text-sm sm:grid-cols-2">
          <SummaryList title="Strongest evidence" items={report.strengths} />
          <SummaryList title="Most important gaps" items={report.gaps} />
        </div>
      )}

      <ol aria-label="Requirements" className="divide-y divide-slate-200 dark:divide-slate-800">
        {report.matches.map((match) => (
          <MatchRow key={match.id} match={match} postingId={postingId} readOnly={readOnly} />
        ))}
      </ol>
    </div>
  )
}

function SummaryList({ title, items }: { title: string; items: string[] }) {
  if (!items.length) return null
  return (
    <section>
      <h3 className="font-semibold">{title}</h3>
      <ul className="mt-1 list-disc space-y-0.5 pl-5 text-slate-700 dark:text-slate-300">
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </section>
  )
}

function VerdictBadge({ verdict }: { verdict: Verdict }) {
  return (
    <span
      title={verdictDescriptions[verdict]}
      className={`inline-flex whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-semibold ring-1 ring-inset ${verdictTones[verdict]}`}
    >
      {verdictLabels[verdict]}
    </span>
  )
}

function MatchRow({ match, postingId, readOnly }: { match: RequirementMatch; postingId: number; readOnly: boolean }) {
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState(false)
  const queryClient = useQueryClient()

  const save = useMutation({
    mutationFn: (changes: { user_verdict: Verdict | null; user_note: string | null }) =>
      unwrap(api.PATCH('/api/v1/requirement_matches/{id}', { params: { path: { id: match.id } }, body: { requirement_match: changes } })),
    onSuccess: ({ match_report }) => {
      queryClient.setQueryData(matchReportQueryKey(postingId), match_report)
      setEditing(false)
    },
  })

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const verdict = String(form.get('user_verdict') ?? '')
    save.mutate({
      user_verdict: verdict ? (verdict as Verdict) : null,
      user_note: String(form.get('user_note') ?? '').trim() || null,
    })
  }

  return (
    <li className="space-y-2 py-3 text-sm">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <p className="text-xs uppercase tracking-wide text-slate-500">{kindLabels[match.requirement_kind]}</p>
          <p className="font-medium">{match.requirement_text}</p>
          {match.reasoning && <p className="mt-1 text-slate-600 dark:text-slate-400">{match.reasoning}</p>}
          {match.user_note && !editing && (
            <p className="mt-1 rounded bg-indigo-50 px-2 py-1 text-indigo-900 dark:bg-indigo-950 dark:text-indigo-100">
              <span className="font-semibold">Your note:</span> {match.user_note}
            </p>
          )}
        </div>
        <div className="flex flex-col items-end gap-1">
          <VerdictBadge verdict={match.verdict} />
          {match.user_verdict && <span className="text-xs text-slate-500">AI said: {verdictLabels[match.ai_verdict]}</span>}
          {!editing && !readOnly && (
            <button
              type="button"
              onClick={() => setEditing(true)}
              aria-label={`Change verdict for ${match.requirement_text}`}
              className="text-xs font-medium text-slate-500 hover:text-slate-900 hover:underline dark:hover:text-slate-100"
            >
              Change
            </button>
          )}
        </div>
      </div>
      {editing && (
        <form onSubmit={handleSubmit} className="space-y-2 rounded-md p-3 ring-1 ring-inset ring-slate-200 dark:ring-slate-800">
          <label className="block text-xs font-medium" htmlFor={`verdict-${match.id}`}>
            Your verdict
          </label>
          <select
            id={`verdict-${match.id}`}
            name="user_verdict"
            defaultValue={match.user_verdict ?? ''}
            className="rounded-md border-0 bg-white py-1.5 pl-3 pr-8 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700"
          >
            <option value="">Keep the AI's verdict ({verdictLabels[match.ai_verdict]})</option>
            {(Object.keys(verdictLabels) as Verdict[]).map((verdict) => (
              <option key={verdict} value={verdict}>
                {verdictLabels[verdict]}
              </option>
            ))}
          </select>
          <label className="block text-xs font-medium" htmlFor={`note-${match.id}`}>
            Note <span className="font-normal text-slate-500">(e.g. evidence to add to your CV)</span>
          </label>
          <textarea
            id={`note-${match.id}`}
            name="user_note"
            rows={2}
            maxLength={2000}
            defaultValue={match.user_note ?? ''}
            className="block w-full rounded-md border-0 bg-white px-3 py-2 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700"
          />
          {save.isError && <Alert tone="error">{save.error.message}</Alert>}
          <div className="flex gap-2">
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? 'Saving…' : 'Save'}
            </Button>
            <Button type="button" variant="secondary" onClick={() => setEditing(false)}>
              Cancel
            </Button>
          </div>
        </form>
      )}
      {match.citations.length > 0 && (
        <div>
          <button
            type="button"
            aria-expanded={open}
            onClick={() => setOpen((value) => !value)}
            className="text-xs font-medium text-indigo-600 hover:underline dark:text-indigo-400"
          >
            {open ? 'Hide evidence' : `Show evidence (${match.citations.length})`}
          </button>
          {open && (
            <ul className="mt-2 space-y-2">
              {match.citations.map((citation) => (
                <li key={citation.id} className="rounded-md bg-slate-50 p-3 ring-1 ring-inset ring-slate-200 dark:bg-slate-950 dark:ring-slate-800">
                  <p className="text-xs font-semibold text-slate-600 dark:text-slate-300">
                    {[citation.document_title, citation.page && `page ${citation.page}`, citation.section].filter(Boolean).join(' · ')}
                  </p>
                  <blockquote className="mt-1 line-clamp-6 whitespace-pre-wrap text-slate-700 dark:text-slate-300">
                    {citation.excerpt}
                  </blockquote>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </li>
  )
}
