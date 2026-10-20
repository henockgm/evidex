import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import type { JobApplication } from '../api/client'
import { baseRoutes, emptyApplicationDetails, json, mockApi, postingDetailDefaults, renderApp, user } from '../test/render'

const basePosting = {
  id: 7,
  title: 'Senior Rails Developer',
  company: 'Acme Oy',
  location: null,
  work_model: null,
  deadline: null,
  source_url: null,
  created_at: '2026-10-20T10:00:00Z',
  updated_at: '2026-10-20T10:00:00Z',
  ...postingDetailDefaults, description: 'Build APIs.',
  requirements: [],
}

const savedEvent: JobApplication['events'][number] = { id: 1, from_status: null, to_status: 'saved', note: null, created_at: '2026-10-20T10:00:00Z' }

describe('Application card', () => {
  it('moves the application to the next status with a note and shows it in the timeline', async () => {
    let application: JobApplication = { ...emptyApplicationDetails, id: 70, status: 'saved', available_transitions: ['preparing', 'applied', 'withdrawn'], events: [savedEvent] }
    let sent: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...basePosting, status: application.status, application } }),
      'POST /api/v1/job_applications/70/transitions': async (request) => {
        sent = await request.json()
        application = {
          ...application,
          status: 'applied',
          available_transitions: ['interviewing', 'offer', 'rejected', 'withdrawn'],
          events: [...application.events, { id: 2, from_status: 'saved', to_status: 'applied', note: 'Via careers page', created_at: '2026-10-21T09:00:00Z' }],
        }
        return json({ application })
      },
    })

    renderApp('/postings/7')
    await userEvent.type(await screen.findByLabelText(/Note for the timeline/), 'Via careers page')
    await userEvent.click(screen.getByRole('button', { name: 'Mark as applied' }))

    expect(await screen.findByRole('button', { name: 'Got an interview' })).toBeInTheDocument()
    expect(sent).toEqual({ to_status: 'applied', note: 'Via careers page' })
    const timeline = screen.getByRole('list', { name: 'Timeline' })
    expect(within(timeline).getByText('Via careers page')).toBeInTheDocument()
    expect(within(timeline).getByText('Applied')).toBeInTheDocument()
    expect(screen.getByLabelText(/Note for the timeline/)).toHaveValue('')
  })

  it('shows why a status change was refused', async () => {
    const application = { ...emptyApplicationDetails, id: 70, status: 'saved', available_transitions: ['applied'], events: [savedEvent] }
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...basePosting, status: 'saved', application } }),
      'POST /api/v1/job_applications/70/transitions': () =>
        new Response(JSON.stringify({ type: 'about:blank', title: 'Status change not allowed', status: 422, detail: "Can't move from saved to applied" }), {
          status: 422,
          headers: { 'Content-Type': 'application/problem+json' },
        }),
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Mark as applied' }))

    expect(await screen.findByRole('alert')).toHaveTextContent("Can't move from saved to applied")
  })

  it('says when an application is closed', async () => {
    const events = [savedEvent, { id: 2, from_status: 'saved', to_status: 'withdrawn', note: null, created_at: '2026-10-21T09:00:00Z' }]
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () =>
        json({ job_posting: { ...basePosting, status: 'withdrawn', application: { ...emptyApplicationDetails, id: 70, status: 'withdrawn', available_transitions: [], events } } }),
    })

    renderApp('/postings/7')

    expect(await screen.findByText('This application is closed.')).toBeInTheDocument()
    expect(screen.queryByLabelText(/Note for the timeline/)).not.toBeInTheDocument()
  })
})

