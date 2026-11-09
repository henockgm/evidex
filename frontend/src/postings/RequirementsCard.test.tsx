import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it } from 'vitest'
import { baseRoutes, emptyApplicationDetails, json, mockApi, postingDetailDefaults, renderApp, user } from '../test/render'

const posting = {
  ...postingDetailDefaults,
  id: 7,
  title: 'Full Stack Developer',
  company: 'Acme Oy',
  location: null,
  work_model: null,
  deadline: null,
  source_url: null,
  status: 'saved',
  created_at: '2026-10-20T10:00:00Z',
  updated_at: '2026-10-20T10:00:00Z',
  description: 'Rakennamme rajapintoja.',
  language: 'fi',
  extraction: { status: 'done', error: null, extracted_at: '2026-11-09T10:00:00Z' },
  requirements: [
    { id: 1, kind: 'required', text: 'Experience with CI/CD tools', source_text: 'Kokemus CI/CD-työkaluista', position: 1 },
    { id: 2, kind: 'required', text: 'Ruby on Rails', source_text: null, position: 2 },
  ],
  application: { ...emptyApplicationDetails, id: 70, status: 'saved', available_transitions: [], events: [] },
}

const requiredList = () => within(screen.getByRole('region', { name: 'Required qualifications' }))

describe('Requirements language', () => {
  beforeEach(() => localStorage.clear())

  it('shows English by default and switches every line to the original wording at once', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => json({ user }), 'GET /api/v1/job_postings/7': () => json({ job_posting: posting }) })

    renderApp('/postings/7')
    const toggle = await screen.findByRole('switch', { name: 'Original wording (Finnish)' })
    expect(toggle).toHaveAttribute('aria-checked', 'false')
    expect(requiredList().getByText('Experience with CI/CD tools')).toBeInTheDocument()
    expect(requiredList().getByRole('button', { name: 'Edit "Experience with CI/CD tools"' })).toBeInTheDocument()

    await userEvent.click(toggle)

    expect(toggle).toHaveAttribute('aria-checked', 'true')
    expect(requiredList().getByText('Kokemus CI/CD-työkaluista')).toHaveAttribute('lang', 'fi')
    // A line the user added has no original and stays in English
    expect(requiredList().getByText('Ruby on Rails')).toBeInTheDocument()
    expect(requiredList().queryByRole('button', { name: /^Edit/ })).not.toBeInTheDocument()
    expect(screen.getByText(/switch it off to edit/)).toBeInTheDocument()
    expect(localStorage.getItem('evidex.requirements.showOriginal')).toBe('true')
  })

  it('has no switch when there is no original wording', async () => {
    const english = {
      ...posting,
      language: 'en',
      requirements: [{ id: 2, kind: 'required', text: 'Ruby on Rails', source_text: null, position: 1 }],
    }
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => json({ user }), 'GET /api/v1/job_postings/7': () => json({ job_posting: english }) })

    renderApp('/postings/7')
    expect(await screen.findByText('Ruby on Rails')).toBeInTheDocument()
    expect(screen.queryByRole('switch')).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Translate to English' })).not.toBeInTheDocument()
  })

  it('offers to translate a posting read before requirements were translated', async () => {
    const legacy = {
      ...posting,
      language: null,
      requirements: [{ id: 1, kind: 'required', text: 'Kokemus CI/CD-työkaluista', source_text: null, position: 1 }],
    }
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: legacy }),
      'POST /api/v1/job_postings/7/translation': () => json({ job_posting: posting }),
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Translate to English' }))

    expect(await screen.findByText(/Run the match report again/)).toBeInTheDocument()
    expect(requiredList().getByText('Experience with CI/CD tools')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Translate to English' })).not.toBeInTheDocument()
    expect(screen.getByRole('switch', { name: 'Original wording (Finnish)' })).toBeInTheDocument()
  })
})
