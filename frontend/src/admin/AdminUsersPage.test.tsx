import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, renderApp, user } from '../test/render'

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
