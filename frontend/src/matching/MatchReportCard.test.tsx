import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import type { MatchReport } from '../api/client'
import { baseRoutes, emptyApplicationDetails, json, mockApi, postingDetailDefaults, problem, renderApp, user } from '../test/render'

const posting = {
  ...postingDetailDefaults,
  id: 7,
  title: 'Senior Rails Developer',
  company: 'Acme Oy',
  location: null,
  work_model: null,
  deadline: null,
  source_url: null,
  status: 'saved',
  created_at: '2026-10-20T10:00:00Z',
  updated_at: '2026-10-20T10:00:00Z',
  description: 'Build APIs.',
  requirements: [],
  application: { ...emptyApplicationDetails, id: 70, status: 'saved', available_transitions: [], events: [] },
}

const doneReport: MatchReport = {
  id: 3,
  job_posting_id: 7,
  version: 2,
  status: 'done',
  error: null,
  model: 'claude-opus-5-5',
  counts: { evidenced: 1, transferable: 0, gap: 1 },
  strengths: ['Rails APIs in production'],
  gaps: ['Kubernetes'],
  created_at: '2026-10-21T10:00:00Z',
  completed_at: '2026-10-21T10:01:00Z',
  matches: [
    {
      id: 1, requirement_id: 11, requirement_kind: 'required', requirement_text: 'Ruby on Rails', verdict: 'evidenced',
      ai_verdict: 'evidenced', user_verdict: null, user_note: null,
      reasoning: 'Built REST APIs with Rails at Acme.',
      citations: [{ id: 5, document_id: 2, document_title: 'My CV', page: 1, section: 'Experience', excerpt: 'Built REST APIs with Ruby on Rails.' }],
    },
    {
      id: 2, requirement_id: 12, requirement_kind: 'required', requirement_text: 'Kubernetes', verdict: 'gap',
      ai_verdict: 'gap', user_verdict: null, user_note: null,
      reasoning: 'Nothing about Kubernetes.', citations: [],
    },
  ],
}

describe('Match report', () => {
  it('runs a report, polls until it is done and shows verdicts with evidence', async () => {
    let calls = 0
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: posting }),
      'GET /api/v1/job_postings/7/match_report': () => {
        calls += 1
        if (calls === 1) return problem(404, 'No match report yet')
        return json({ match_report: doneReport })
      },
      'POST /api/v1/job_postings/7/match_reports': () =>
        json({ match_report: { ...doneReport, status: 'pending', counts: { evidenced: 0, transferable: 0, gap: 0 }, matches: [] } }, 202),
    })

    renderApp('/postings/7')
    expect(await screen.findByText(/No report yet/)).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Run match report' }))
    expect(await screen.findByRole('button', { name: 'Preparing the report…' })).toBeDisabled()

    const summary = await screen.findByRole('list', { name: 'Summary' }, { timeout: 4000 })
    expect(summary).toHaveTextContent('Evidenced1Transferable0Gap1')
    expect(screen.getByText('Rails APIs in production')).toBeInTheDocument()

    const rows = screen.getByRole('list', { name: 'Requirements' })
    expect(within(rows).getByText('Built REST APIs with Rails at Acme.')).toBeInTheDocument()
    await userEvent.click(within(rows).getByRole('button', { name: 'Show evidence (1)' }))
    expect(within(rows).getByText('My CV · page 1 · Experience')).toBeInTheDocument()
    expect(within(rows).getByText('Built REST APIs with Ruby on Rails.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Run again' })).toBeEnabled()
  })

  it('explains why a report can not run', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: posting }),
      'GET /api/v1/job_postings/7/match_report': () => problem(404, 'No match report yet'),
      'POST /api/v1/job_postings/7/match_reports': () =>
        new Response(JSON.stringify({ type: 'about:blank', title: 'Library is empty', status: 422, detail: 'Upload your CV to the career library first.' }), {
          status: 422,
          headers: { 'Content-Type': 'application/problem+json' },
        }),
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Run match report' }))

    await waitFor(() => expect(screen.getByText('Upload your CV to the career library first.')).toBeInTheDocument())
  })

  it('lets the user override a verdict and add a note', async () => {
    let report = doneReport
    let sent: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: posting }),
      'GET /api/v1/job_postings/7/match_report': () => json({ match_report: report }),
      'PATCH /api/v1/requirement_matches/2': async (request) => {
        sent = await request.json()
        report = {
          ...report,
          counts: { evidenced: 1, transferable: 1, gap: 0 },
          matches: [report.matches[0], { ...report.matches[1], verdict: 'transferable', user_verdict: 'transferable', user_note: 'Ran k3s at home.' }],
        }
        return json({ match_report: report })
      },
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Change verdict for Kubernetes' }))
    await userEvent.selectOptions(screen.getByLabelText('Your verdict'), 'Transferable')
    await userEvent.type(screen.getByLabelText(/^Note/), 'Ran k3s at home.')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    expect(await screen.findByText('AI said: Gap')).toBeInTheDocument()
    expect(screen.getByText('Ran k3s at home.')).toBeInTheDocument()
    expect(screen.getByRole('list', { name: 'Summary' })).toHaveTextContent('Evidenced1Transferable1Gap0')
    expect(sent).toEqual({ requirement_match: { user_verdict: 'transferable', user_note: 'Ran k3s at home.' } })
  })

  it('shows older versions read-only', async () => {
    const older = { ...doneReport, id: 2, version: 1, counts: { evidenced: 0, transferable: 0, gap: 2 },
      matches: doneReport.matches.map((m) => ({ ...m, verdict: 'gap' as const, ai_verdict: 'gap' as const, citations: [] })) }
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: posting }),
      'GET /api/v1/job_postings/7/match_report': () => json({ match_report: doneReport }),
      'GET /api/v1/job_postings/7/match_reports': () =>
        json({
          match_reports: [doneReport, older].map(({ id, version, status, model, counts, created_at, completed_at }) => ({
            id, version, status, model, counts, created_at, completed_at,
          })),
        }),
      'GET /api/v1/match_reports/2': () => json({ match_report: older }),
    })

    renderApp('/postings/7')
    const picker = await screen.findByLabelText('Version')
    expect(picker).toHaveTextContent('v2 (latest) · 1 evidenced, 0 transferable, 1 gaps')

    await userEvent.selectOptions(picker, '2')
    expect(await screen.findByText(/You're looking at version 1/)).toBeInTheDocument()
    expect(screen.getByRole('list', { name: 'Summary' })).toHaveTextContent('Evidenced0Transferable0Gap2')
    expect(screen.queryByRole('button', { name: /Change verdict/ })).not.toBeInTheDocument()
  })
})
