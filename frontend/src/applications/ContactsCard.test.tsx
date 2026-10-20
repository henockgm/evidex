import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import type { ApplicationContact } from '../api/client'
import { baseRoutes, emptyApplicationDetails, json, mockApi, problem, renderApp, user } from '../test/render'

const posting = {
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
}

describe('Contacts', () => {
  it('adds, shows and removes a contact', async () => {
    let contacts: ApplicationContact[] = []
    let sent: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () =>
        json({ job_posting: { ...posting, application: { ...emptyApplicationDetails, id: 70, status: 'saved', available_transitions: [], events: [], contacts } } }),
      'POST /api/v1/job_applications/70/contacts': async (request) => {
        sent = await request.json()
        const contact = { id: 1, name: 'Ana Virtanen', role: 'Recruiter', email: 'ana@example.com', phone: '+358 40 123 4567', notes: null }
        contacts = [contact]
        return json({ contact }, 201)
      },
      'DELETE /api/v1/contacts/1': () => {
        contacts = []
        return new Response(null, { status: 204 })
      },
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Add contact' }))
    await userEvent.type(screen.getByLabelText('Name'), 'Ana Virtanen')
    await userEvent.type(screen.getByLabelText('Role'), 'Recruiter')
    await userEvent.type(screen.getByLabelText('Email'), 'ana@example.com')
    await userEvent.type(screen.getByLabelText('Phone'), '+358 40 123 4567')
    await userEvent.click(screen.getByRole('button', { name: 'Add contact' }))

    expect(await screen.findByRole('link', { name: 'ana@example.com' })).toHaveAttribute('href', 'mailto:ana@example.com')
    expect(screen.getByRole('link', { name: '+358 40 123 4567' })).toHaveAttribute('href', 'tel:+358401234567')
    expect(sent).toEqual({ contact: { name: 'Ana Virtanen', role: 'Recruiter', email: 'ana@example.com', phone: '+358 40 123 4567', notes: null } })

    await userEvent.click(screen.getByRole('button', { name: 'Remove Ana Virtanen' }))
    await waitFor(() => expect(screen.queryByText('Ana Virtanen')).not.toBeInTheDocument())
  })

  it('shows field errors', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () =>
        json({ job_posting: { ...posting, application: { ...emptyApplicationDetails, id: 70, status: 'saved', available_transitions: [], events: [] } } }),
      'POST /api/v1/job_applications/70/contacts': () => problem(422, 'Validation failed', { email: ['Email is invalid'] }),
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Add contact' }))
    await userEvent.type(screen.getByLabelText('Name'), 'Ana')
    await userEvent.click(screen.getByRole('button', { name: 'Add contact' }))

    expect(await screen.findByText('Email is invalid')).toBeInTheDocument()
  })
})
