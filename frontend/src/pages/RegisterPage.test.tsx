import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, problem, renderApp } from '../test/render'

describe('RegisterPage', () => {
  const signedOut = { 'GET /api/v1/me': () => problem(401, 'Authentication required') }

  async function fillIn(password: string) {
    await userEvent.type(await screen.findByLabelText('Email'), 'ada@example.com')
    await userEvent.type(screen.getByLabelText('Password'), password)
    await userEvent.click(screen.getByRole('button', { name: 'Create account' }))
  }

  it('shows the confirmation message', async () => {
    mockApi({
      ...baseRoutes,
      ...signedOut,
      'POST /api/v1/registration': () => json({ message: 'Check your inbox to confirm your email address.' }, 202),
    })

    renderApp('/register')
    await fillIn('correct horse battery staple')

    expect(await screen.findByText('Check your inbox to confirm your email address.')).toBeInTheDocument()
  })

  it('shows field errors next to the password', async () => {
    mockApi({
      ...baseRoutes,
      ...signedOut,
      'POST /api/v1/registration': () =>
        problem(422, 'Validation failed', { password: ['has appeared in a known data breach; choose a different one'] }),
    })

    renderApp('/register')
    await fillIn('password1234')

    expect(await screen.findByText(/Password has appeared in a known data breach/)).toBeInTheDocument()
    expect(screen.getByLabelText('Password')).toHaveAttribute('aria-invalid', 'true')
  })
})
