import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, reauthenticationRequired, renderApp, user } from '../test/render'

const admin = { ...user, admin: true, two_factor_enabled: true }

const adminUser = (overrides = {}) => ({
  id: 2,
  email_address: 'grace@example.com',
  name: 'Grace',
  admin: false,
  email_verified: true,
  has_password: true,
  two_factor_enabled: false,
  providers: ['google_oauth2'],
  locked_until: null,
  active_sessions: 2,
  last_active_at: '2026-10-22T09:00:00Z',
  ai_calls_last_30_days: 7,
  created_at: '2026-10-20T10:00:00Z',
  ...overrides,
})

describe('AdminUsersPage', () => {
  it('lists accounts with how they sign in and searches them', async () => {
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user: admin }),
      'GET /api/v1/admin/users': (request) =>
        new URL(request.url).searchParams.get('q') === 'linus'
          ? json({ users: [], meta: { page: 1, per_page: 25, total: 0, total_pages: 0 } })
          : json({
              users: [adminUser(), adminUser({ id: 3, email_address: 'new@example.com', email_verified: false, providers: [] })],
              meta: { page: 1, per_page: 25, total: 2, total_pages: 1 },
            }),
    })

    renderApp('/admin/users')

    expect(await screen.findByText('grace@example.com')).toBeInTheDocument()
    expect(screen.getByText(/Signs in with Password, Google · 2 active sessions/)).toBeInTheDocument()
    expect(screen.getAllByText(/7 AI calls in 30 days/)).toHaveLength(2)
    expect(screen.getByText('Unverified')).toBeInTheDocument()

    await userEvent.type(screen.getByRole('searchbox', { name: 'Search by email or name' }), 'linus')
    await userEvent.click(screen.getByRole('button', { name: 'Search' }))
    expect(await screen.findByText('No accounts found.')).toBeInTheDocument()
    expect(requests.some((request) => request.url.includes('q=linus'))).toBe(true)
  })
})

describe('AdminUserActions', () => {
  it('locks an account after asking, and confirms it is the admin first', async () => {
    let confirmed = false
    let locked = false
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user: admin }),
      'GET /api/v1/admin/users': () =>
        json({
          users: [adminUser({ suspended_at: locked ? '2026-10-23T10:00:00Z' : null, active_sessions: locked ? 0 : 2 })],
          meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
        }),
      'POST /api/v1/me/reauthentication': () => {
        confirmed = true
        return json({ recently_authenticated_until: '2026-10-23T10:10:00Z' }, 201)
      },
      'POST /api/v1/admin/users/2/lock': () => {
        if (!confirmed) return reauthenticationRequired()
        locked = true
        return json({ user: adminUser({ suspended_at: '2026-10-23T10:00:00Z' }) })
      },
    })

    renderApp('/admin/users')
    await userEvent.click(await screen.findByRole('button', { name: 'Lock' }))
    await userEvent.click(screen.getByRole('button', { name: 'Lock account' }))

    const dialog = await screen.findByRole('dialog', { name: "Confirm it's you" })
    await userEvent.type(within(dialog).getByLabelText('Password'), 'admin password')
    await userEvent.type(within(dialog).getByLabelText(/code/i), '123456')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Confirm' }))

    expect(await screen.findByText('Locked by an admin')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Unlock' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Sign out everywhere' })).not.toBeInTheDocument()
    expect(requests.filter((request) => request.url.endsWith('/admin/users/2/lock'))).toHaveLength(2)
  })

  it("doesn't offer actions on the admin's own account", async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user: admin }),
      'GET /api/v1/admin/users': () =>
        json({ users: [adminUser({ id: admin.id, admin: true })], meta: { page: 1, per_page: 25, total: 1, total_pages: 1 } }),
    })

    renderApp('/admin/users')

    expect(await screen.findByText('grace@example.com')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Lock' })).not.toBeInTheDocument()
  })
})
