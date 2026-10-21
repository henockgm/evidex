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
})
