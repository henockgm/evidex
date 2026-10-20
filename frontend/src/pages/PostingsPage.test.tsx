import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, problem, renderApp, user } from '../test/render'

const posting = {
  id: 7,
  title: 'Senior Rails Developer',
  company: 'Acme Oy',
  location: 'Helsinki',
  work_model: 'hybrid',
  deadline: '2026-11-30',
  source_url: 'https://jobs.example.com/7',
  created_at: '2026-10-20T10:00:00Z',
  updated_at: '2026-10-20T10:00:00Z',
}

describe('Job postings', () => {
  it('lists postings with their key details', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings': () => json({ job_postings: [posting] }),
    })

    renderApp('/postings')

    expect(await screen.findByRole('link', { name: /Senior Rails Developer/ })).toHaveAttribute('href', '/postings/7')
    expect(screen.getByText(/Acme Oy · Helsinki · Hybrid · Deadline Nov 30, 2026/)).toBeInTheDocument()
  })

  it('saves a pasted posting and opens it', async () => {
    let saved: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'POST /api/v1/job_postings': async (request) => {
        saved = await request.json()
        return json({ job_posting: { ...posting, description: 'Build APIs.', requirements: [] } }, 201)
      },
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...posting, description: 'Build APIs.', requirements: [] } }),
    })

    renderApp('/postings/new')
    await userEvent.type(await screen.findByLabelText('Job title'), 'Senior Rails Developer')
    await userEvent.type(screen.getByLabelText('Company'), 'Acme Oy')
    await userEvent.selectOptions(screen.getByLabelText('Work model'), 'Hybrid')
    await userEvent.type(screen.getByLabelText('Job ad text'), 'Build APIs.')
    await userEvent.click(screen.getByRole('button', { name: 'Save posting' }))

    expect(await screen.findByRole('heading', { name: 'Senior Rails Developer' })).toBeInTheDocument()
    expect(screen.getByText('Build APIs.')).toBeInTheDocument()
    expect(saved).toEqual({
      job_posting: {
        title: 'Senior Rails Developer',
        company: 'Acme Oy',
        location: null,
        work_model: 'hybrid',
        deadline: null,
        source_url: null,
        description: 'Build APIs.',
      },
    })
  })

  it('shows field errors from the API', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'POST /api/v1/job_postings': () => problem(422, 'Validation failed', { source_url: ['Link must be an http or https link'] }),
    })

    renderApp('/postings/new')
    await userEvent.type(await screen.findByLabelText('Job title'), 'Dev')
    await userEvent.type(screen.getByLabelText('Company'), 'Acme')
    await userEvent.type(screen.getByLabelText('Job ad text'), 'Text')
    await userEvent.click(screen.getByRole('button', { name: 'Save posting' }))

    expect(await screen.findByText('Link must be an http or https link')).toBeInTheDocument()
  })

  it('edits a posting, sending the changed form', async () => {
    let current = { ...posting, description: 'Build APIs.', requirements: [] }
    let sent: { job_posting: Record<string, unknown> } | undefined
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: current }),
      'PATCH /api/v1/job_postings/7': async (request) => {
        sent = await request.json()
        current = { ...current, ...(sent!.job_posting as object) }
        return json({ job_posting: current })
      },
    })

    renderApp('/postings/7/edit')
    const title = await screen.findByLabelText('Job title')
    expect(title).toHaveValue('Senior Rails Developer')
    expect(screen.getByLabelText('Work model')).toHaveValue('hybrid')
    await userEvent.clear(title)
    await userEvent.type(title, 'Lead Rails Developer')
    await userEvent.clear(screen.getByLabelText('Application deadline'))
    await userEvent.click(screen.getByRole('button', { name: 'Save changes' }))

    expect(await screen.findByRole('heading', { name: 'Lead Rails Developer' })).toBeInTheDocument()
    expect(sent?.job_posting).toMatchObject({ title: 'Lead Rails Developer', deadline: null, company: 'Acme Oy' })
  })

  it('asks for confirmation before deleting', async () => {
    let deleted = false
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...posting, description: 'Build APIs.', requirements: [] } }),
      'GET /api/v1/job_postings': () => json({ job_postings: [] }),
      'DELETE /api/v1/job_postings/7': () => {
        deleted = true
        return new Response(null, { status: 204 })
      },
    })

    renderApp('/postings/7')
    await userEvent.click(await screen.findByRole('button', { name: 'Delete' }))
    expect(deleted).toBe(false)
    await userEvent.click(screen.getByRole('button', { name: 'Delete posting' }))

    expect(await screen.findByText(/No postings yet/)).toBeInTheDocument()
    expect(deleted).toBe(true)
  })

  it('adds and removes requirements', async () => {
    type Req = { id: number; kind: string; text: string; position: number }
    let requirements: Req[] = [{ id: 1, kind: 'required', text: 'Ruby on Rails', position: 1 }]
    let added: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...posting, description: 'Build APIs.', requirements } }),
      'POST /api/v1/job_postings/7/requirements': async (request) => {
        added = await request.json()
        const requirement = { id: 2, kind: 'preferred', text: 'pgvector', position: 1 }
        requirements = [...requirements, requirement]
        return json({ requirement }, 201)
      },
      'DELETE /api/v1/requirements/1': () => {
        requirements = requirements.filter((r) => r.id !== 1)
        return new Response(null, { status: 204 })
      },
    })

    renderApp('/postings/7')
    const required = await screen.findByRole('region', { name: 'Required qualifications' })
    expect(within(required).getByText('Ruby on Rails')).toBeInTheDocument()

    await userEvent.type(screen.getByLabelText('Add to nice to have'), 'pgvector{Enter}')
    const preferred = screen.getByRole('region', { name: 'Nice to have' })
    expect(await within(preferred).findByText('pgvector')).toBeInTheDocument()
    expect(added).toEqual({ requirement: { kind: 'preferred', text: 'pgvector' } })

    await userEvent.click(screen.getByRole('button', { name: 'Remove "Ruby on Rails"' }))
    await waitFor(() => expect(screen.queryByText('Ruby on Rails')).not.toBeInTheDocument())
  })
})
