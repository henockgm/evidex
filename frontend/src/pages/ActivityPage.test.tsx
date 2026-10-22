import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, renderApp, user } from '../test/render'

const event = (id: number, action: string, details = {}) => ({
  id,
  action,
  created_at: '2026-10-22T09:00:00Z',
  ip_address: '203.0.113.7',
  device: 'Firefox on Windows',
  details,
})

describe('ActivityPage', () => {
  it('lists security events with readable details and pages back in time', async () => {
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user }),
      'GET /api/v1/me/activity': (request) =>
        new URL(request.url).searchParams.get('page') === '2'
          ? json({ events: [event(1, 'registered')], meta: { page: 2, per_page: 20, total: 21, total_pages: 2 } })
          : json({
              events: [
                event(3, 'signed_in', { method: 'google_oauth2', second_factor: 'recovery_code' }),
                event(2, 'sign_in_failed'),
              ],
              meta: { page: 1, per_page: 20, total: 21, total_pages: 2 },
            }),
    })

    renderApp('/settings/activity')

    expect(await screen.findByText('with Google using a recovery code')).toBeInTheDocument()
    expect(screen.getByText('Failed sign-in attempt')).toHaveClass('text-rose-700')
    expect(screen.getAllByText('Firefox on Windows · 203.0.113.7')).toHaveLength(2)

    await userEvent.click(screen.getByRole('button', { name: 'Older' }))
    expect(await screen.findByText('Account created')).toBeInTheDocument()
    expect(requests.some((request) => request.url.endsWith('/api/v1/me/activity?page=2'))).toBe(true)
  })
})
