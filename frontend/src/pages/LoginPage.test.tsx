import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, problem, renderApp, user } from '../test/render'

describe('LoginPage', () => {
  it('signs in with the CSRF token and goes to the dashboard', async () => {
    let signedIn = false
    const requests = mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => (signedIn ? json({ user }) : problem(401, 'Authentication required')),
      'POST /api/v1/session': () => {
        signedIn = true
        return json({ user }, 201)
      },
    })

    renderApp('/login')
    await userEvent.type(await screen.findByLabelText('Email'), 'ada@example.com')
    await userEvent.type(screen.getByLabelText('Password'), 'correct horse battery staple')
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('heading', { name: 'Welcome, Ada' })).toBeInTheDocument()
    const signIn = requests.find((request) => request.method === 'POST')!
    expect(signIn.headers.get('X-CSRF-Token')).toBe('csrf-123')
    expect(await signIn.clone().json()).toEqual({ email_address: 'ada@example.com', password: 'correct horse battery staple' })
  })

  it('shows the server error for bad credentials', async () => {
    mockApi({
      ...baseRoutes,
      'GET /api/v1/me': () => problem(401, 'Authentication required'),
      'POST /api/v1/session': () => problem(401, 'Invalid email or password, or the account is temporarily locked.'),
    })

    renderApp('/login')
    await userEvent.type(await screen.findByLabelText('Email'), 'ada@example.com')
    await userEvent.type(screen.getByLabelText('Password'), 'wrong')
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Invalid email or password')
  })

  it('explains OAuth errors passed back in the URL', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => problem(401, 'Authentication required') })

    renderApp('/login?error=account_exists')

    expect(await screen.findByRole('alert')).toHaveTextContent('An account with this email already exists')
  })

  it('renders Google sign-in as a form POST carrying the CSRF token', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => problem(401, 'Authentication required') })

    renderApp('/login')
    const button = await screen.findByRole('button', { name: 'Sign in with Google' })
    const form = button.closest('form')!

    expect(form).toHaveAttribute('method', 'post')
    expect(form).toHaveAttribute('action', '/auth/google_oauth2')
    await waitFor(() => expect(form.querySelector('input[name=authenticity_token]')).toHaveValue('csrf-123'))
  })

  it('redirects signed-out visitors from protected pages', async () => {
    mockApi({ ...baseRoutes, 'GET /api/v1/me': () => problem(401, 'Authentication required') })

    renderApp('/settings/security')

    expect(await screen.findByRole('heading', { name: 'Sign in to Evidex' })).toBeInTheDocument()
  })
})
