import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, emptyApplicationDetails, json, mockApi, postingDetailDefaults, renderApp, user } from '../test/render'

const existing = {
  id: 7,
  title: 'Senior Rails Developer',
  company: 'Acme Oy',
  location: 'Helsinki',
  work_model: 'hybrid',
  deadline: '2026-11-30',
  source_url: 'https://jobs.example.com/7',
  status: 'applied',
  created_at: '2026-10-20T10:00:00Z',
  updated_at: '2026-10-20T10:00:00Z',
}

const draft = {
  title: 'Senior Rails Developer',
  company: 'Acme Oy',
  location: 'Helsinki',
  work_model: 'hybrid',
  deadline: '2026-11-30',
  source_url: 'https://jobs.example.com/7',
  description: 'Build APIs.',
}

const created = {
  ...existing,
  ...postingDetailDefaults,
  id: 8,
  status: 'saved',
  description: 'Build APIs.',
  requirements: [],
  application: {
    ...emptyApplicationDetails,
    id: 80,
    status: 'saved',
    available_transitions: ['preparing', 'applied', 'withdrawn'],
    events: [],
  },
}

const duplicateProblem = () =>
  new Response(
    JSON.stringify({
      type: 'urn:evidex:problem:possible-duplicate',
      title: "You've already saved this job ad",
      status: 409,
      detail: 'Open the saved posting, or send confirm_duplicate: true to save it again.',
      possible_duplicates: [existing],
    }),
    { status: 409, headers: { 'Content-Type': 'application/problem+json' } },
  )

describe('Adding a job posting', () => {
  it('warns when the imported link is an ad already saved, naming the posting with a link to it', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'POST /api/v1/job_posting_import': () => json({ draft, structured_data: true, possible_duplicates: [existing] }),
    })

    renderApp('/postings/new')
    await userEvent.type(await screen.findByLabelText('Link to the job ad'), 'https://jobs.example.com/7?utm_source=x')
    await userEvent.click(screen.getByRole('button', { name: 'Fetch' }))

    const warning = (await screen.findByText("You've already saved this job ad:")).closest('[role="status"]') as HTMLElement
    expect(within(warning).getByRole('link', { name: 'Senior Rails Developer at Acme Oy' })).toHaveAttribute('href', '/postings/7')
    expect(warning).toHaveTextContent('Applied · added Oct 20, 2026')
    expect(screen.getByLabelText('Job title')).toHaveValue('Senior Rails Developer')
  })

  it('asks before saving an ad that is already saved, and saves it on "Save anyway"', async () => {
    const saves: unknown[] = []
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'POST /api/v1/job_postings': async (request) => {
        const body = (await request.json()) as { confirm_duplicate: boolean }
        saves.push(body)
        return body.confirm_duplicate ? json({ job_posting: created }, 201) : duplicateProblem()
      },
      'GET /api/v1/job_postings/8': () => json({ job_posting: created }),
    })

    renderApp('/postings/new')
    await userEvent.type(await screen.findByLabelText('Job title'), 'Senior Rails Developer')
    await userEvent.type(screen.getByLabelText('Company'), 'Acme Oy')
    await userEvent.type(screen.getByLabelText('Link to the ad'), 'https://jobs.example.com/7')
    await userEvent.type(screen.getByLabelText('Job ad text'), 'Build APIs.')
    await userEvent.click(screen.getByRole('button', { name: 'Save posting' }))

    expect(await screen.findByRole('link', { name: 'Senior Rails Developer at Acme Oy' })).toHaveAttribute('href', '/postings/7')
    expect(screen.queryByText(/confirm_duplicate/)).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Save anyway' }))

    expect(await screen.findByRole('heading', { name: 'Senior Rails Developer' })).toBeInTheDocument()
    expect(saves).toEqual([
      expect.objectContaining({ confirm_duplicate: false }),
      expect.objectContaining({ confirm_duplicate: true, job_posting: expect.objectContaining({ source_url: 'https://jobs.example.com/7' }) }),
    ])
  })

  it('offers "Save anyway" straight after importing an ad that is already saved', async () => {
    const saves: unknown[] = []
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'POST /api/v1/job_posting_import': () => json({ draft, structured_data: true, possible_duplicates: [existing] }),
      'POST /api/v1/job_postings': async (request) => {
        saves.push(await request.json())
        return json({ job_posting: created }, 201)
      },
      'GET /api/v1/job_postings/8': () => json({ job_posting: created }),
    })

    renderApp('/postings/new')
    await userEvent.type(await screen.findByLabelText('Link to the job ad'), 'https://jobs.example.com/7')
    await userEvent.click(screen.getByRole('button', { name: 'Fetch' }))
    await userEvent.click(await screen.findByRole('button', { name: 'Save anyway' }))

    expect(await screen.findByRole('heading', { name: 'Senior Rails Developer' })).toBeInTheDocument()
    expect(saves).toEqual([expect.objectContaining({ confirm_duplicate: true })])
  })
})
