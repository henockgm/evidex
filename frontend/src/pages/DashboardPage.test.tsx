import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, renderApp, user } from '../test/render'

const statusCounts = { saved: 3, preparing: 1, applied: 2, interviewing: 1, offer: 0, accepted: 0, rejected: 1, no_response: 0, withdrawn: 0 }

describe('Dashboard', () => {
  it('shows counts per status, deadlines, next actions and activity', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/dashboard': () =>
        json({
          status_counts: statusCounts,
          total: 8,
          upcoming_interviews: [
            { job_posting_id: 4, title: 'Platform Engineer', company: 'Beta', interview_id: 9, round: 'Technical', format: 'video', scheduled_at: '2026-10-23T11:00:00Z' },
          ],
          upcoming_deadlines: [{ job_posting_id: 1, title: 'Rails Developer', company: 'Acme', deadline: '2026-10-25' }],
          next_actions: [
            { job_posting_id: 2, title: 'Platform Engineer', company: 'Beta', next_action: 'Send portfolio', next_action_on: '2026-10-18', overdue: true },
          ],
          no_reply: [
            { job_posting_id: 5, job_application_id: 50, title: 'Data Engineer', company: 'Delta', applied_on: '2026-09-20', days_waiting: 30 },
          ],
          recent_activity: [
            { job_posting_id: 3, title: 'Backend Developer', company: 'Gamma', from_status: 'saved', to_status: 'applied', created_at: '2026-10-20T09:00:00Z' },
          ],
        }),
    })

    renderApp('/')

    const applied = await screen.findByRole('link', { name: 'Applied: 2' })
    expect(applied).toHaveAttribute('href', '/postings?status=applied')
    expect(screen.getByRole('link', { name: 'All postings (8) →' })).toBeInTheDocument()

    const deadlines = screen.getByRole('heading', { name: 'Upcoming deadlines' }).closest('section')!
    expect(within(deadlines).getByText('Oct 25, 2026')).toBeInTheDocument()

    expect(screen.getByText('Send portfolio')).toBeInTheDocument()
    expect(screen.getByText(/Overdue · Oct 18, 2026/)).toBeInTheDocument()
    expect(screen.getByText('Backend Developer')).toBeInTheDocument()
    expect(screen.getByText(/Beta · Technical/)).toBeInTheDocument()
    expect(screen.getByText(/Applied Sep 20, 2026 · 30 days/)).toBeInTheDocument()
  })

  it('closes a stale application as no response', async () => {
    let noReply = [{ job_posting_id: 5, job_application_id: 50, title: 'Data Engineer', company: 'Delta', applied_on: '2026-09-20', days_waiting: 30 }]
    let sent: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/dashboard': () =>
        json({
          status_counts: statusCounts, total: 8, upcoming_interviews: [], upcoming_deadlines: [], next_actions: [],
          no_reply: noReply, recent_activity: [],
        }),
      'POST /api/v1/job_applications/50/transitions': async (request) => {
        sent = await request.json()
        noReply = []
        return json({ application: {} })
      },
    })

    renderApp('/')
    await userEvent.click(await screen.findByRole('button', { name: 'Mark Data Engineer as no response' }))

    await waitFor(() => expect(screen.queryByRole('heading', { name: 'No reply yet' })).not.toBeInTheDocument())
    expect(sent).toEqual({ to_status: 'no_response', note: 'No reply from the employer' })
  })

  it('invites the user to add a first posting', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/dashboard': () =>
        json({
          status_counts: { saved: 0, preparing: 0, applied: 0, interviewing: 0, offer: 0, accepted: 0, rejected: 0, no_response: 0, withdrawn: 0 },
          total: 0,
          upcoming_interviews: [],
          upcoming_deadlines: [],
          next_actions: [],
          no_reply: [],
          recent_activity: [],
        }),
    })

    renderApp('/')

    expect(await screen.findByRole('link', { name: 'Add your first posting →' })).toHaveAttribute('href', '/postings/new')
    expect(screen.queryByRole('heading', { name: 'Pipeline' })).not.toBeInTheDocument()
  })
})
