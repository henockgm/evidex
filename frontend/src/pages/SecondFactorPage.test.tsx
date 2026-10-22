import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, problem, renderApp, user } from '../test/render'

describe('Two-factor sign-in', () => {
  it('asks for a code after the password, then signs in', async () => {
    let signedIn = false
    let csrfFetches = 0
    let codeSent: unknown
    mockApi({
      ...baseRoutes,
      'GET /api/v1/csrf_token': () => {
        csrfFetches += 1
        return json({ csrf_token: `csrf-${csrfFetches}` })
      },
      'GET /api/v1/me': () => (signedIn ? json({ user: { ...user, two_factor_enabled: true } }) : problem(401, 'Authentication required')),
      'POST /api/v1/session': () => json({ second_factor_required: true }, 202),
      'POST /api/v1/session/second_factor': async (request) => {
        codeSent = await request.json()
        expect(request.headers.get('X-CSRF-Token')).toBe('csrf-2')
        signedIn = true
        return json({ user: { ...user, two_factor_enabled: true } }, 201)
      },
    })

    renderApp('/login')
    await userEvent.type(await screen.findByLabelText('Email'), 'ada@example.com')
    await userEvent.type(screen.getByLabelText('Password'), 'correct horse battery staple')
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    await userEvent.type(await screen.findByLabelText('Code from your authenticator app'), '123456')
    await userEvent.click(screen.getByRole('button', { name: 'Verify' }))

    expect(await screen.findByRole('heading', { name: 'Welcome, Ada' })).toBeInTheDocument()
    expect(codeSent).toEqual({ code: '123456' })
  })

  it('accepts a recovery code and explains wrong and expired codes', async () => {
    let attempts = 0
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => problem(401, 'Authentication required'),
      'POST /api/v1/session/second_factor': () => {
        attempts += 1
        return attempts === 1 ? problem(422, "That code didn't work. Check your authenticator app and try again.") : problem(401, 'Sign-in expired')
      },
    })

    renderApp('/login/verify')
    await userEvent.click(await screen.findByRole('button', { name: 'Use a recovery code' }))
    await userEvent.type(screen.getByLabelText('Recovery code'), 'abcde-12345')
    await userEvent.click(screen.getByRole('button', { name: 'Verify' }))
    expect(await screen.findByRole('alert')).toHaveTextContent("That code didn't work")

    await userEvent.click(screen.getByRole('button', { name: 'Verify' }))
    expect(await screen.findByText(/Sign-in expired/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Verify' })).not.toBeInTheDocument()
  })
})
