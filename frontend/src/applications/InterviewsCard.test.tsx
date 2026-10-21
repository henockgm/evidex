import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import type { Interview } from '../api/client'
import { baseRoutes, emptyApplicationDetails, json, mockApi, postingDetailDefaults, renderApp, user } from '../test/render'

const posting = {
  ...postingDetailDefaults,
  id: 7,
  title: 'Senior Rails Developer',
  company: 'Acme Oy',
  location: null,
  work_model: null,
  deadline: null,
  source_url: null,
  created_at: '2026-10-20T10:00:00Z',
  updated_at: '2026-10-20T10:00:00Z',
  description: 'Build APIs.',
  requirements: [],
}

describe('Interviews', () => {
  it('schedules an interview in local time, moving the application to interviewing, then marks it done', async () => {
    let interviews: Interview[] = []
    let status = 'applied'
    let sent: { interview: Record<string, unknown> } | undefined
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () =>
        json({
          job_posting: {
            ...posting,
            status,
            application: { ...emptyApplicationDetails, id: 70, status, available_transitions: [], events: [], interviews },
          },
        }),
      'POST /api/v1/job_applications/70/interviews': async (request) => {
        sent = await request.json()
        const interview: Interview = {
          id: 1, round: 'Technical', scheduled_at: String(sent!.interview.scheduled_at), format: 'video',
          location: 'https://meet.example.com/abc', status: 'scheduled', notes: null,
        }
        interviews = [interview]
        status = 'interviewing'
        return json({ interview }, 201)
      },
      'PATCH /api/v1/interviews/1': () => {
        interviews = [{ ...interviews[0], status: 'completed' }]
        return json({ interview: interviews[0] })
      },
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Add interview' }))
    await userEvent.type(screen.getByLabelText('Date and time'), '2026-10-28T14:00')
    await userEvent.type(screen.getByLabelText('Round'), 'Technical')
    await userEvent.selectOptions(screen.getByLabelText('Format'), 'Video call')
    await userEvent.type(screen.getByLabelText('Location or meeting link'), 'https://meet.example.com/abc')
    await userEvent.click(screen.getByRole('button', { name: 'Add interview' }))

    expect(await screen.findByRole('link', { name: 'Join link' })).toHaveAttribute('href', 'https://meet.example.com/abc')
    expect(sent?.interview.scheduled_at).toBe(new Date('2026-10-28T14:00').toISOString())
    expect(screen.getAllByText('Interviewing').length).toBeGreaterThan(0)

    await userEvent.click(screen.getByRole('button', { name: 'Mark done' }))
    expect(await screen.findByText('Done')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Mark done' })).not.toBeInTheDocument()
  })
})
