import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, renderApp, user } from '../test/render'

const admin = { ...user, admin: true, two_factor_enabled: true }
const summary = { calls: 3, failed_calls: 1, input_tokens: 120000, output_tokens: 8000, estimated_cost_usd: 0.64, models: ['claude-opus-5-5'], unpriced_models: [] }

describe('AdminAiUsagePage', () => {
  it('shows calls, tokens and estimated cost per account and switches the period', async () => {
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => json({ user: admin }),
      'GET /api/v1/admin/ai_usage': (request) =>
        json({ days: Number(new URL(request.url).searchParams.get('days')), totals: summary, users: [{ ...summary, user: { id: 5, email_address: 'grace@example.com' } }] }),
    })

    renderApp('/admin/ai-usage')

    expect(await screen.findByRole('link', { name: 'grace@example.com' })).toBeInTheDocument()
    expect(screen.getAllByText('$0.64')).toHaveLength(2)
    expect(screen.getByText('(1 failed)')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: '90 days' }))
    expect(requests.some((request) => request.url.endsWith('/api/v1/admin/ai_usage?days=90'))).toBe(true)
  })
})
