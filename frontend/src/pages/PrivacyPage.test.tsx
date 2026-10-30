import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { CONTACT_EMAIL } from '../site'
import { baseRoutes, mockApi, problem, renderApp } from '../test/render'

describe('PrivacyPage', () => {
  it('can be read without an account', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => problem(401, 'Authentication required') })

    renderApp('/privacy')

    expect(await screen.findByRole('heading', { level: 1, name: 'Privacy' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: CONTACT_EMAIL })).toHaveAttribute('href', `mailto:${CONTACT_EMAIL}`)
  })
})
