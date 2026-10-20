import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, emptyApplicationDetails, json, mockApi, postingDetailDefaults, problem, renderApp, user } from '../test/render'

const posting = {
  id: 7,
  title: 'Senior Rails Developer',
  company: 'Acme Oy',
  location: 'Helsinki',
  work_model: 'hybrid',
  deadline: '2026-11-30',
  source_url: 'https://jobs.example.com/7',
  status: 'saved',
  created_at: '2026-10-20T10:00:00Z',
  updated_at: '2026-10-20T10:00:00Z',
}

const application = {
  ...emptyApplicationDetails,
  id: 70,
  status: 'saved',
  available_transitions: ['preparing', 'applied', 'withdrawn'],
  events: [{ id: 1, from_status: null, to_status: 'saved', note: null, created_at: '2026-10-20T10:00:00Z' }],
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
        return json({ job_posting: { ...posting, ...postingDetailDefaults, description: 'Build APIs.', requirements: [], application } }, 201)
      },
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...posting, ...postingDetailDefaults, description: 'Build APIs.', requirements: [], application } }),
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
        employment_type: null,
        seniority: null,
        salary: null,
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
    let current = { ...posting, ...postingDetailDefaults, description: 'Build APIs.', requirements: [], application }
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
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...posting, ...postingDetailDefaults, description: 'Build APIs.', requirements: [], application } }),
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
      'GET /api/v1/job_postings/7': () => json({ job_posting: { ...posting, ...postingDetailDefaults, description: 'Build APIs.', requirements, application } }),
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

  it('imports a posting from a link into the form for review', async () => {
    let fetched: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'POST /api/v1/job_posting_import': async (request) => {
        fetched = await request.json()
        return json({
          draft: {
            title: 'Platform Engineer',
            company: 'Acme Oy',
            location: 'Espoo, FI',
            work_model: 'remote',
            deadline: '2026-12-01',
            source_url: 'https://jobs.example.com/9',
            description: 'Run Rails in production.',
          },
          structured_data: true,
        })
      },
    })

    renderApp('/postings/new')
    await userEvent.type(await screen.findByLabelText('Link to the job ad'), 'https://jobs.example.com/9')
    await userEvent.click(screen.getByRole('button', { name: 'Fetch' }))

    expect(await screen.findByText(/Imported the job details the site publishes/)).toBeInTheDocument()
    expect(fetched).toEqual({ url: 'https://jobs.example.com/9' })
    expect(screen.getByLabelText('Job title')).toHaveValue('Platform Engineer')
    expect(screen.getByLabelText('Work model')).toHaveValue('remote')
    expect(screen.getByLabelText('Application deadline')).toHaveValue('2026-12-01')
    expect(screen.getByLabelText('Job ad text')).toHaveValue('Run Rails in production.')
  })

  it('suggests pasting the text when a link can\'t be imported', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'POST /api/v1/job_posting_import': () =>
        new Response(
          JSON.stringify({ type: 'about:blank', title: "Couldn't import that link", status: 422, detail: 'The website answered with an error (HTTP 403)' }),
          { status: 422, headers: { 'Content-Type': 'application/problem+json' } },
        ),
    })

    renderApp('/postings/new')
    await userEvent.type(await screen.findByLabelText('Link to the job ad'), 'https://www.linkedin.com/jobs/view/1')
    await userEvent.click(screen.getByRole('button', { name: 'Fetch' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('HTTP 403')
    expect(screen.getByRole('alert')).toHaveTextContent('paste the ad')
  })

  it('filters by status, search and deadline through the URL and pages through results', async () => {
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings': (request) => {
        const page = Number(new URL(request.url).searchParams.get('page') ?? 1)
        return json({
          job_postings: [{ ...posting, id: page, title: `Result page ${page}` }],
          meta: { page, per_page: 1, total: 2, total_pages: 2 },
        })
      },
    })

    renderApp('/postings')
    expect(await screen.findByText('Showing 1–1 of 2')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Applied' }))
    await userEvent.click(screen.getByRole('button', { name: 'Interviewing' }))
    await userEvent.selectOptions(screen.getByLabelText('Deadline'), 'Due within 7 days')
    await userEvent.type(screen.getByLabelText('Search postings'), 'rails')

    await waitFor(() => {
      const last = new URL(requests.at(-1)!.url).searchParams
      expect(Object.fromEntries(last)).toEqual({ status: 'applied,interviewing', deadline: 'upcoming', q: 'rails', sort: 'newest', page: '1' })
    })
    expect(screen.getByRole('button', { name: 'Applied' })).toHaveAttribute('aria-pressed', 'true')

    await userEvent.click(screen.getByRole('button', { name: 'Next' }))
    expect(await screen.findByText('Result page 2')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Next' })).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }))
    await waitFor(() => expect(screen.getByLabelText('Search postings')).toHaveValue(''))
    expect(screen.getByRole('button', { name: 'Applied' })).toHaveAttribute('aria-pressed', 'false')
  })

  it('tells apart "no postings yet" and "no matches"', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/job_postings': () => json({ job_postings: [], meta: { page: 1, per_page: 20, total: 0, total_pages: 0 } }),
    })

    renderApp('/postings?status=offer')

    expect(await screen.findByText('No postings match these filters.')).toBeInTheDocument()
  })
})
