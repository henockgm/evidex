import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import type { JobApplication } from '../api/client'
import { baseRoutes, emptyApplicationDetails, json, mockApi, renderApp, user } from '../test/render'

const posting = {
  id: 7,
  title: 'Senior Rails Developer',
  company: 'Acme Oy',
  location: null,
  work_model: null,
  deadline: null,
  source_url: null,
  status: 'applied',
  created_at: '2026-10-20T10:00:00Z',
  updated_at: '2026-10-20T10:00:00Z',
  description: 'Build APIs.',
  requirements: [],
}

describe('Application details', () => {
  it('edits dates, next action, notes and links', async () => {
    let application: JobApplication = {
      ...emptyApplicationDetails,
      id: 70,
      status: 'applied',
      applied_on: '2026-10-18',
      available_transitions: ['interviewing'],
      events: [],
    }
    let sent: { job_application: Record<string, unknown> } | undefined
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...posting, application } }),
      'PATCH /api/v1/job_applications/70': async (request) => {
        sent = await request.json()
        application = { ...application, ...(sent!.job_application as Partial<JobApplication>) }
        return json({ application })
      },
    })

    renderApp('/postings/7')
    expect(await screen.findByText('Oct 18, 2026')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Edit details' }))
    await userEvent.type(screen.getByLabelText('Next action'), 'Follow up with Ana')
    await userEvent.type(screen.getByLabelText('Next action by'), '2026-10-25')
    await userEvent.type(screen.getByLabelText('Notes'), 'Referred by Ana.')
    await userEvent.click(screen.getByRole('button', { name: 'Add link' }))
    await userEvent.type(screen.getByLabelText('Link 1 label'), 'Portal')
    await userEvent.type(screen.getByLabelText('Link 1 URL'), 'https://jobs.example.com/status')
    await userEvent.click(screen.getByRole('button', { name: 'Save details' }))

    expect(await screen.findByRole('link', { name: 'Portal' })).toHaveAttribute('href', 'https://jobs.example.com/status')
    expect(screen.getByText('Follow up with Ana')).toBeInTheDocument()
    expect(sent?.job_application).toEqual({
      applied_on: '2026-10-18',
      next_action: 'Follow up with Ana',
      next_action_on: '2026-10-25',
      notes: 'Referred by Ana.',
      links: [{ label: 'Portal', url: 'https://jobs.example.com/status' }],
    })
  })
})
