import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { vi } from 'vitest'
import { AppRoutes } from '../App'
import { resetCsrfToken } from '../api/client'

export function renderApp(path: string) {
  resetCsrfToken()
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[path]}>
        <AppRoutes />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

type Handler = (request: Request) => Response | Promise<Response>

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

export const problem = (status: number, title: string, errors?: Record<string, string[]>) =>
  new Response(JSON.stringify({ type: 'about:blank', title, status, errors }), {
    status,
    headers: { 'Content-Type': 'application/problem+json' },
  })

export const user = {
  id: 1,
  email_address: 'ada@example.com',
  name: 'Ada',
  email_verified: true,
  has_password: true,
  identities: [],
  created_at: '2026-10-20T10:00:00Z',
}

/** Stubs fetch with "METHOD /path" handlers; returns the recorded requests. */
export function mockApi(routes: Record<string, Handler>) {
  const requests: Request[] = []
  const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const request = input instanceof Request ? input : new Request(new URL(String(input), 'http://localhost'), init)
    requests.push(request)
    const key = `${request.method} ${new URL(request.url, 'http://localhost').pathname}`
    const handler = routes[key]
    if (!handler) return problem(404, `No mock for ${key}`)
    return handler(request)
  })
  vi.stubGlobal('fetch', fetchMock)
  return requests
}

export const baseRoutes: Record<string, Handler> = {
  'GET /api/v1/csrf_token': () => json({ csrf_token: 'csrf-123' }),
  'GET /api/v1/auth/providers': () =>
    json({ providers: [{ id: 'google_oauth2', label: 'Google', path: '/auth/google_oauth2' }] }),
}

/** Application fields a fresh application has before the user fills anything in. */
export const emptyApplicationDetails = {
  applied_on: null,
  next_action: null,
  next_action_on: null,
  notes: null,
  links: [] as { label?: string | null; url: string }[],
  contacts: [],
}
