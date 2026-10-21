import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
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

describe('AI extraction', () => {
  it('starts extraction, polls until done and shows what was filled in', async () => {
    let calls = 0
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'POST /api/v1/job_postings/7/extraction': () =>
        json({ job_posting: { ...posting, extraction: { status: 'pending', error: null, extracted_at: null } } }, 202),
      'GET /api/v1/job_postings/7': () => {
        calls += 1
        if (calls === 1) return json({ job_posting: posting })
        return json({
          job_posting: {
            ...posting,
            seniority: 'Senior',
            keywords: ['Ruby', 'PostgreSQL'],
            requirements: [{ id: 1, kind: 'required', text: 'PostgreSQL', position: 1 }],
            extraction: { status: 'done', error: null, extracted_at: '2026-10-20T11:00:00Z' },
          },
        })
      },
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Read with AI' }))

    expect(await screen.findByRole('button', { name: 'Reading the ad…' })).toBeDisabled()
    expect(await screen.findByText(/Check the details and requirements below/, {}, { timeout: 4000 })).toBeInTheDocument()
    expect(screen.getByRole('list', { name: 'Keywords' })).toHaveTextContent('RubyPostgreSQL')
    expect(screen.getByText('Senior')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Read again' })).toBeEnabled()
  })

  it('explains a failed extraction and the daily limit', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () =>
        json({ job_posting: { ...posting, extraction: { status: 'failed', error: 'The AI declined to process this text', extracted_at: null } } }),
      'POST /api/v1/job_postings/7/extraction': () => problem(429, 'Daily AI limit reached'),
    })

    renderApp('/postings/7')

    expect(await screen.findByText('The AI declined to process this text')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Read with AI' }))
    expect(await screen.findByText('Daily AI limit reached')).toBeInTheDocument()
  })

  it('needs a confirmed email, and hides itself when the server has no AI', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user: { ...user, email_verified: false } }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: posting }),
    })
    const { unmount } = renderApp('/postings/7')
    expect(await screen.findByRole('button', { name: 'Read with AI' })).toBeDisabled()
    expect(screen.getAllByText('Confirm your email address to use AI features.').length).toBeGreaterThan(0)
    unmount()

    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user: { ...user, ai_configured: false } }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: posting }),
    })
    renderApp('/postings/7')
    expect(await screen.findByRole('heading', { name: 'Senior Rails Developer' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Read with AI' })).not.toBeInTheDocument()
  })
})
