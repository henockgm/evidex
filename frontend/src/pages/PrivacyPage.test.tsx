import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { CONTACT_EMAIL, SOURCE_URL } from '../site'
import { baseRoutes, mockApi, problem, renderApp } from '../test/render'

describe('PrivacyPage', () => {
  it('can be read without an account', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => problem(401, 'Authentication required') })

    renderApp('/privacy')

    expect(await screen.findByRole('heading', { level: 1, name: 'Privacy' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: CONTACT_EMAIL })).toHaveAttribute('href', `mailto:${CONTACT_EMAIL}`)
  })

  it('is linked from the footer on the sign-in page', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => problem(401, 'Authentication required') })

    renderApp('/login')

    const footer = await screen.findByRole('contentinfo')
    expect(within(footer).getByRole('link', { name: 'Source on GitHub' })).toHaveAttribute('href', SOURCE_URL)
    expect(within(footer).getByRole('link', { name: 'Contact' })).toHaveAttribute('href', `mailto:${CONTACT_EMAIL}`)

    await userEvent.click(within(footer).getByRole('link', { name: 'Privacy' }))
    expect(await screen.findByRole('heading', { level: 1, name: 'Privacy' })).toBeInTheDocument()
  })
})
