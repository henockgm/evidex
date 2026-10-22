import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, problem, reauthenticationRequired, renderApp, user } from '../test/render'

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

  it('changes the password after confirming it is the user', async () => {
    let confirmed = false
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/me/sessions': () => json({ sessions: sessions.slice(0, 1) }),
      'POST /api/v1/me/reauthentication': () => {
        confirmed = true
        return json({ recently_authenticated_until: '2026-10-22T10:10:00Z' }, 201)
      },
      'PATCH /api/v1/me/password': () => (confirmed ? json({ user }) : reauthenticationRequired()),
    })

    renderApp('/settings/security')
    await userEvent.type(await screen.findByLabelText('New password'), 'a brand new long password')
    await userEvent.click(screen.getByRole('button', { name: 'Save password' }))

    const dialog = await screen.findByRole('dialog', { name: "Confirm it's you" })
    expect(within(dialog).queryByLabelText(/code/i)).not.toBeInTheDocument()
    await userEvent.type(within(dialog).getByLabelText('Password'), 'my old password')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Confirm' }))

    expect(await screen.findByText('Password saved. Other devices were signed out.')).toBeInTheDocument()
    const reauth = requests.find((request) => request.url.endsWith('/reauthentication'))!
    expect(await reauth.json()).toEqual({ password: 'my old password' })
  })

  it('asks for the email address before deleting the account', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/me/sessions': () => json({ sessions: sessions.slice(0, 1) }),
      'DELETE /api/v1/me': () => problem(422, 'Validation failed', { confirm_email: ['Type your email address to confirm'] }),
    })

    renderApp('/settings/security')
    await userEvent.type(await screen.findByLabelText('Type ada@example.com to confirm'), 'bob@example.com')
    await userEvent.click(screen.getByRole('button', { name: 'Delete my account' }))

    expect(await screen.findByText('Type your email address to confirm')).toBeInTheDocument()
  })
})
