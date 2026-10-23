import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, renderApp, user } from '../test/render'

const admin = { ...user, admin: true, two_factor_enabled: true }
const overview = { users: 12, verified_users: 9, two_factor_users: 3, active_sessions: 5, ai_calls_last_30_days: 41 }

describe('Admin area', () => {
  it('shows admins the overview and an Admin link', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => json({ user: admin }), 'GET /api/v1/admin/overview': () => json(overview) })

    renderApp('/admin')

    expect(await screen.findByText('41')).toBeInTheDocument()
    expect(screen.getByText('AI calls, last 30 days')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Admin' })).toHaveAttribute('href', '/admin')
  })

  it('asks admins to turn on two-factor sign-in first', async () => {
    const requests = mockApi({ ...baseRoutes, 'GET /api/v1/me': () => json({ user: { ...admin, two_factor_enabled: false } }) })

    renderApp('/admin')

    expect(await screen.findByText(/Turn on two-factor sign-in to use the admin area/)).toBeInTheDocument()
    expect(requests.some((request) => request.url.includes('/api/v1/admin/'))).toBe(false)
  })

  it('sends other users home without an Admin link', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => json({ user }), 'GET /api/v1/dashboard': () => json({}) })

    renderApp('/admin')

    expect(await screen.findByRole('heading', { name: /Welcome/ })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Admin' })).not.toBeInTheDocument()
  })
})
