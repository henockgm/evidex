import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, problem, renderApp, user } from '../test/render'

const sessions = { 'GET /api/v1/me/sessions': () => json({ sessions: [] }) }
const codes = Array.from({ length: 10 }, (_, i) => `code${i}-abcde`)

describe('Two-factor settings', () => {
  it('sets up with a QR code, confirms a code and shows the recovery codes once', async () => {
    let me = user
    mockApi({
      ...baseRoutes,
      ...sessions,
      'GET /api/v1/me': () => json({ user: me }),
      'POST /api/v1/me/two_factor/setup': () =>
        json({ secret: 'JBSWY3DPEHPK3PXP', otpauth_uri: 'otpauth://totp/Evidex:ada@example.com', qr_code: 'data:image/svg+xml;base64,PHN2Zy8+' }),
      'POST /api/v1/me/two_factor': async (request) => {
        const { code } = (await request.json()) as { code: string }
        if (code !== '654321') return problem(422, 'Validation failed', { code: ['Code is incorrect or expired'] })
        me = { ...user, two_factor_enabled: true, recovery_codes_remaining: 10 }
        return json({ user: me, recovery_codes: codes }, 201)
      },
    })

    renderApp('/settings/security')
    await userEvent.click(await screen.findByRole('button', { name: 'Turn on two-factor sign-in' }))
    expect(await screen.findByRole('img', { name: 'QR code for your authenticator app' })).toHaveAttribute('src', 'data:image/svg+xml;base64,PHN2Zy8+')
    expect(screen.getByText('JBSWY3DPEHPK3PXP')).toBeInTheDocument()

    await userEvent.type(screen.getByLabelText('6-digit code'), '111111')
    await userEvent.click(screen.getByRole('button', { name: 'Turn on' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Code is incorrect or expired')

    await userEvent.clear(screen.getByLabelText('6-digit code'))
    await userEvent.type(screen.getByLabelText('6-digit code'), '654321')
    await userEvent.click(screen.getByRole('button', { name: 'Turn on' }))

    const list = await screen.findByRole('list', { name: 'Recovery codes' })
    expect(list.querySelectorAll('li')).toHaveLength(10)
    expect(screen.getByRole('link', { name: 'Download as text' })).toHaveAttribute('download', 'evidex-recovery-codes.txt')

    await userEvent.click(screen.getByRole('button', { name: "I've saved them" }))
    expect(await screen.findByText(/10 of 10 recovery codes left/)).toBeInTheDocument()
  })

  it('turns off with a code', async () => {
    let me = { ...user, two_factor_enabled: true, recovery_codes_remaining: 2 }
    mockApi({
      ...baseRoutes,
      ...sessions,
      'GET /api/v1/me': () => json({ user: me }),
      'DELETE /api/v1/me/two_factor': () => {
        me = { ...user }
        return json({ user: me })
      },
    })

    renderApp('/settings/security')
    expect(await screen.findByText(/2 of 10 recovery codes left \(consider replacing them\)/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Turn off' }))
    await userEvent.type(screen.getByLabelText('Code from your app or a recovery code'), '123456')
    await userEvent.click(screen.getByRole('button', { name: 'Turn off' }))

    await waitFor(() => expect(screen.getByRole('button', { name: 'Turn on two-factor sign-in' })).toBeInTheDocument())
  })
})
