import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, renderApp, user } from '../test/render'

const sessions = [
  { id: 1, current: true, ip_address: '127.0.0.1', user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) Chrome/140.0', created_at: '2026-10-20T10:00:00Z', last_active_at: '2026-10-20T10:00:00Z' },
  { id: 2, current: false, ip_address: '10.0.0.2', user_agent: 'Mozilla/5.0 (Windows NT 10.0) Firefox/140.0', created_at: '2026-10-19T10:00:00Z', last_active_at: '2026-10-19T10:00:00Z' },
]

describe('SecurityPage', () => {
  it('lists devices and signs out another one', async () => {
    let current = sessions
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/me/sessions': () => json({ sessions: current }),
      'DELETE /api/v1/me/sessions/2': () => {
        current = sessions.slice(0, 1)
        return new Response(null, { status: 204 })
      },
    })

    renderApp('/settings/security')

    const firefox = (await screen.findByText('Firefox on Windows')).closest('li')!
    expect(screen.getByText('This device')).toBeInTheDocument()
    await userEvent.click(within(firefox).getByRole('button', { name: 'Sign out' }))

    await screen.findByText('Chrome on macOS')
    expect(screen.queryByText('Firefox on Windows')).not.toBeInTheDocument()
    expect(requests.some((request) => request.method === 'DELETE')).toBe(true)
  })

  it("won't let an OAuth-only user disconnect their only sign-in method", async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () =>
        json({
          user: {
            ...user,
            has_password: false,
            identities: [{ id: 5, provider: 'google_oauth2', label: 'Google', email: 'ada@example.com', created_at: '2026-10-20T10:00:00Z' }],
          },
        }),
      'GET /api/v1/me/sessions': () => json({ sessions: sessions.slice(0, 1) }),
    })

    renderApp('/settings/security')

    expect(await screen.findByRole('button', { name: 'Disconnect' })).toBeDisabled()
    expect(screen.getByRole('heading', { name: 'Add a password' })).toBeInTheDocument()
  })
})
