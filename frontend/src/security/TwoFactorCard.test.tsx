import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { baseRoutes, json, mockApi, problem, reauthenticationRequired, renderApp, user } from '../test/render'

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

  it('turns off after confirming it is the user with password and code', async () => {
    let me = { ...user, two_factor_enabled: true, recovery_codes_remaining: 2 }
    let confirmed = false
    const requests = mockApi({
      ...baseRoutes,
      ...sessions,
      'GET /api/v1/me': () => json({ user: me }),
      'POST /api/v1/me/reauthentication': async (request) => {
        const body = (await request.json()) as { password: string; code: string }
        if (body.code !== '123456') return problem(422, 'Validation failed', { code: ['Code is incorrect or expired'] })
        confirmed = body.password === 'my password'
        return json({ recently_authenticated_until: '2026-10-22T10:10:00Z' }, 201)
      },
      'DELETE /api/v1/me/two_factor': () => {
        if (!confirmed) return reauthenticationRequired()
        me = { ...user }
        return json({ user: me })
      },
    })

    renderApp('/settings/security')
    expect(await screen.findByText(/2 of 10 recovery codes left \(consider replacing them\)/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Turn off' }))
    await userEvent.click(screen.getByRole('button', { name: 'Turn off' }))

    const dialog = await screen.findByRole('dialog', { name: "Confirm it's you" })
    await userEvent.type(within(dialog).getByLabelText('Password'), 'my password')
    await userEvent.type(within(dialog).getByLabelText('Code from your app or a recovery code'), '000000')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Confirm' }))
    expect(await within(dialog).findByText('Code is incorrect or expired')).toBeInTheDocument()

    await userEvent.clear(within(dialog).getByLabelText('Code from your app or a recovery code'))
    await userEvent.type(within(dialog).getByLabelText('Code from your app or a recovery code'), '123456')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Confirm' }))

    await waitFor(() => expect(screen.getByRole('button', { name: 'Turn on two-factor sign-in' })).toBeInTheDocument())
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(requests.filter((request) => request.method === 'DELETE')).toHaveLength(2)
  })

  it('changes nothing when the confirmation is cancelled', async () => {
    mockApi({
      ...baseRoutes,
      ...sessions,
      'GET /api/v1/me': () => json({ user: { ...user, two_factor_enabled: true, recovery_codes_remaining: 10 } }),
      'POST /api/v1/me/two_factor/recovery_codes': () => reauthenticationRequired(),
    })

    renderApp('/settings/security')
    await userEvent.click(await screen.findByRole('button', { name: 'Replace recovery codes' }))
    await userEvent.click(screen.getByRole('button', { name: 'Replace codes' }))
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Cancel' }))

    expect(await screen.findByRole('alert')).toHaveTextContent("Nothing was changed because you didn't confirm it's you.")
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })
})
