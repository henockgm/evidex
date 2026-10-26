import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import type { Document } from '../api/client'
import { baseRoutes, json, mockApi, problem, renderApp, user } from '../test/render'

const cv: Document = {
  id: 1,
  title: 'CV 2026',
  kind: 'cv',
  primary: true,
  status: 'pending',
  error: null,
  filename: 'cv.pdf',
  content_type: 'application/pdf',
  byte_size: 48_000,
  page_count: 0,
  character_count: 0,
  chunk_count: 0,
  processed_at: null,
  created_at: '2026-10-21T10:00:00Z',
  updated_at: '2026-10-21T10:00:00Z',
}

describe('Career library', () => {
  it('uploads a file as multipart form data with the CSRF token', async () => {
    let documents: Document[] = []
    let upload: Request | undefined
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/documents': () => json({ documents }),
      'POST /api/v1/documents': (request) => {
        upload = request
        documents = [cv]
        return json({ document: cv }, 201)
      },
    })

    renderApp('/library')
    expect(await screen.findByText('No documents yet. Start with your CV.')).toBeInTheDocument()

    const file = new File(['%PDF-1.4 test'], 'cv.pdf', { type: 'application/pdf' })
    await userEvent.upload(screen.getByLabelText('File'), file)
    await userEvent.type(screen.getByLabelText('Title'), 'CV 2026')
    await userEvent.click(screen.getByRole('button', { name: 'Upload' }))

    expect(await screen.findByText('Primary CV')).toBeInTheDocument()
    expect(upload!.headers.get('Content-Type')).toMatch(/^multipart\/form-data; boundary=/)
    expect(upload!.headers.get('X-CSRF-Token')).toBe('csrf-123')
    // Read the raw multipart body. jsdom's File loses its name and content when Node's
    // fetch serialises it, so the filename is checked in the live upload test instead.
    const body = await upload!.text()
    expect(body).toMatch(/name="file"; filename="[^"]+"\r\nContent-Type: application\/pdf/)
    expect(body).toMatch(/name="title"\r\n\r\nCV 2026/)
    expect(body).toMatch(/name="kind"\r\n\r\ncv/)
    expect(screen.getByRole('link', { name: 'Download' })).toHaveAttribute('href', '/api/v1/documents/1/file')
  })

  it('shows why a file was rejected', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/documents': () => json({ documents: [] }),
      'POST /api/v1/documents': () =>
        problem(422, 'Validation failed', { file: ['File must be a PDF, Word (.docx), Markdown or plain text file'] }),
    })

    renderApp('/library')
    await userEvent.upload(await screen.findByLabelText('File'), new File(['MZ'], 'tool.pdf', { type: 'application/pdf' }))
    await userEvent.click(screen.getByRole('button', { name: 'Upload' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('must be a PDF, Word (.docx), Markdown or plain text file')
  })

  it('makes a CV primary and deletes a document after confirming', async () => {
    let documents: Document[] = [cv, { ...cv, id: 2, title: 'Older CV', primary: false }]
    let patched: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/documents': () => json({ documents }),
      'PATCH /api/v1/documents/2': async (request) => {
        patched = await request.json()
        documents = [{ ...cv, primary: false }, { ...cv, id: 2, title: 'Older CV', primary: true }]
        return json({ document: documents[1] })
      },
      'DELETE /api/v1/documents/1': () => {
        documents = documents.filter((d) => d.id !== 1)
        return new Response(null, { status: 204 })
      },
    })

    renderApp('/library')
    await userEvent.click(await screen.findByRole('button', { name: 'Make primary' }))
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Make primary' })).toBeInTheDocument())
    expect(patched).toEqual({ document: { primary: true } })

    await userEvent.click(screen.getByRole('button', { name: 'Delete CV 2026' }))
    await userEvent.click(screen.getByRole('button', { name: 'Delete document' }))
    await waitFor(() => expect(screen.queryByText('CV 2026')).not.toBeInTheDocument())
  })

  it('polls until a document is read, shows its text, and retries a failure', async () => {
    let status: Document['status'] = 'processing'
    let retried = false
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/documents': () => {
        const current = { ...cv, status, page_count: status === 'ready' ? 2 : 0, chunk_count: status === 'ready' ? 3 : 0 }
        status = status === 'processing' ? 'ready' : status
        return json({
          documents: [
            current,
            { ...cv, id: 2, title: 'Scan', primary: false, status: retried ? 'pending' : 'failed', error: retried ? null : 'No text found.' },
          ],
        })
      },
      'GET /api/v1/documents/1/text': () => json({ pages: ['Alex Example - Backend Developer', 'Skills: Ruby'] }),
      'POST /api/v1/documents/2/retry': () => {
        retried = true
        return json({ document: { ...cv, id: 2, status: 'pending' } }, 202)
      },
    })

    renderApp('/library')
    expect(await screen.findByText('Reading…')).toBeInTheDocument()
    expect(await screen.findByText(/2 pages, 3 passages/, {}, { timeout: 4000 })).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'View text' }))
    expect(await screen.findByRole('region', { name: 'Extracted text' })).toHaveTextContent('Page 2Skills: Ruby')

    expect(screen.getByText('No text found.')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Retry' }))
    await waitFor(() => expect(retried).toBe(true))
  })

  it('searches the library and highlights the words', async () => {
    let searched: string | null = null
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/documents': () => json({ documents: [{ ...cv, status: 'ready' }] }),
      'GET /api/v1/library/search': (request) => {
        searched = new URL(request.url).searchParams.get('q')
        return json({
          results: [
            {
              chunk_id: 9, document_id: 1, document_title: 'CV 2026', page: 2, section: 'Skills',
              content: 'Skills\n\nRuby, Rails, PostgreSQL, RSpec', score: 0.0328, matched_by: ['semantic', 'keyword'],
            },
          ],
        })
      },
    })

    renderApp('/library')
    await userEvent.type(await screen.findByLabelText('Search your library'), 'postgresql skills{Enter}')

    const results = await screen.findByRole('list', { name: 'Search results' })
    expect(searched).toBe('postgresql skills')
    expect(results).toHaveTextContent('CV 2026· page 2· Skills· words and meaning')
    expect(results.querySelector('mark')).toHaveTextContent('Skills')
    expect(results).toHaveTextContent('Skills · Ruby, Rails, PostgreSQL, RSpec')
  })

  it('turns uploads off in the shared demo and hides the security settings link', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user: { ...user, demo: true } }),
      'GET /api/v1/documents': () => json({ documents: [{ ...cv, status: 'ready' }] }),
    })

    renderApp('/library')

    expect(await screen.findByText(/Uploads are turned off in the demo/)).toBeInTheDocument()
    expect(screen.queryByLabelText('File')).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Security' })).not.toBeInTheDocument()
  })
})

