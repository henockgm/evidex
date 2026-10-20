import { render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import App from './App'

describe('App', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('shows the API status once loaded', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            name: 'Evidex',
            api_version: 'v1',
            environment: 'test',
            database: 'ok',
            time: '2026-10-20T10:00:00Z',
          }),
          { status: 200 },
        ),
      ),
    )

    render(<App />)

    expect(await screen.findByText('v1')).toBeInTheDocument()
    expect(screen.getByText('ok')).toBeInTheDocument()
  })

  it('shows an alert when the API is down', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('', { status: 503 })))

    render(<App />)

    expect(await screen.findByRole('alert')).toHaveTextContent('failed with 503')
  })
})
