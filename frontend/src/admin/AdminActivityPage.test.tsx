import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, renderApp, user } from '../test/render'

const admin = { ...user, admin: true, two_factor_enabled: true }
const meta = { page: 1, per_page: 50, total: 2, total_pages: 1 }

describe('AdminActivityPage', () => {
  it('lists events across accounts, names the acting admin and filters by kind', async () => {
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user: admin }),
      'GET /api/v1/admin/audit_events': () =>
        json({
          events: [
            {
              id: 2,
              action: 'admin_locked',
              created_at: '2026-10-23T09:00:00Z',
              user: { id: 5, email_address: 'grace@example.com' },
              ip_address: '203.0.113.7',
              device: 'Firefox on Windows',
              details: {},
              admin_email_address: 'ada@example.com',
            },
            { id: 1, action: 'sign_in_failed', created_at: '2026-10-23T08:00:00Z', user: null, details: {} },
          ],
          meta,
        }),
    })

    renderApp('/admin/activity')

    const account = await screen.findByRole('link', { name: 'grace@example.com' })
    expect(screen.getByText('Account locked by an administrator', { selector: 'p' })).toBeInTheDocument()
    expect(account.closest('p')).toHaveTextContent(
      'grace@example.com · by ada@example.com · Firefox on Windows · 203.0.113.7',
    )
    expect(screen.getByText('Unknown account')).toBeInTheDocument()

    await userEvent.selectOptions(screen.getByLabelText('Kind of event'), 'sign_in_failed')
    expect(requests.some((request) => request.url.includes('event_action=sign_in_failed'))).toBe(true)
  })
})
