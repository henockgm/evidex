import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
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

  const run = useMutation({
    mutationFn: () =>
      unwrap(api.POST('/api/v1/job_postings/{job_posting_id}/match_reports', { params: { path: { job_posting_id: postingId } } })),
    onSuccess: ({ match_report }) => queryClient.setQueryData(matchReportQueryKey(postingId), match_report),
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
          {report?.status === 'done' && report.completed_at && (
            <span className="text-sm text-slate-500">
              Version {report.version} · {dateTime.format(new Date(report.completed_at))}
            </span>
          )}
        </div>

        {!isPending && !report && !run.isPending && (
          <p className="text-sm text-slate-500">
            No report yet. It needs requirements on this posting and at least one document in your library.
          </p>
        )}

        {report?.status === 'done' && <ReportBody report={report} />}
      </div>
    </Card>
  )
}

function ReportBody({ report }: { report: MatchReport }) {
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
          <MatchRow key={match.id} match={match} />
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

function MatchRow({ match }: { match: RequirementMatch }) {
  const [open, setOpen] = useState(false)

  return (
    <li className="space-y-2 py-3 text-sm">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <p className="text-xs uppercase tracking-wide text-slate-500">{kindLabels[match.requirement_kind]}</p>
          <p className="font-medium">{match.requirement_text}</p>
          {match.reasoning && <p className="mt-1 text-slate-600 dark:text-slate-400">{match.reasoning}</p>}
        </div>
        <VerdictBadge verdict={match.verdict} />
      </div>
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
