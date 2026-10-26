import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, renderApp, user } from '../test/render'

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
})
