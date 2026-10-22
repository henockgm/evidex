import { useMutation } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { ApiError, api, unwrap, type User } from '../api/client'
import { useAuthChanged, useMe } from '../auth/useAuth'
import { Alert, Button, Card, Field } from '../components/ui'

type Stage = { kind: 'idle' } | { kind: 'setup'; secret: string; qrCode: string } | { kind: 'codes'; codes: string[] }

function errorText(error: Error | null) {
  if (!error) return null
  if (error instanceof ApiError) return error.fieldErrors('code')[0] ?? error.problem?.detail ?? error.problem?.title ?? error.message
  return error.message
}

function codeFrom(event: FormEvent<HTMLFormElement>) {
  return String(new FormData(event.currentTarget).get('code') ?? '').trim()
}

export function TwoFactorCard() {
  const { data: user } = useMe()
  const authChanged = useAuthChanged()
  const [stage, setStage] = useState<Stage>({ kind: 'idle' })
  const [action, setAction] = useState<'disable' | 'regenerate' | null>(null)

  const setup = useMutation({
    mutationFn: () => unwrap(api.POST('/api/v1/me/two_factor/setup')),
    onSuccess: ({ secret, qr_code }) => setStage({ kind: 'setup', secret, qrCode: qr_code }),
  })
  const enable = useMutation({
    mutationFn: (code: string) => unwrap(api.POST('/api/v1/me/two_factor', { body: { code } })),
    onSuccess: ({ user: updated, recovery_codes }) => {
      authChanged(updated as User)
      setStage({ kind: 'codes', codes: recovery_codes })
    },
  })
  const disable = useMutation({
    mutationFn: (code: string) => unwrap(api.DELETE('/api/v1/me/two_factor', { body: { code } })),
    onSuccess: ({ user: updated }) => {
      authChanged(updated)
      setAction(null)
    },
  })
  const regenerate = useMutation({
    mutationFn: (code: string) => unwrap(api.POST('/api/v1/me/two_factor/recovery_codes', { body: { code } })),
    onSuccess: ({ user: updated, recovery_codes }) => {
      authChanged(updated as User)
      setAction(null)
      setStage({ kind: 'codes', codes: recovery_codes })
    },
  })

  if (!user) return null

  if (stage.kind === 'codes') return <RecoveryCodes codes={stage.codes} onDone={() => setStage({ kind: 'idle' })} />

  if (stage.kind === 'setup') {
    return (
      <Card title="Turn on two-factor sign-in" description="Scan the QR code with an authenticator app, then enter the 6-digit code it shows.">
        <div className="flex flex-col gap-6 sm:flex-row">
          <img src={stage.qrCode} alt="QR code for your authenticator app" className="h-44 w-44 rounded bg-white p-2" />
          <form
            onSubmit={(event) => {
              event.preventDefault()
              enable.mutate(codeFrom(event))
            }}
            className="flex-1 space-y-4"
          >
            <p className="text-sm text-slate-600 dark:text-slate-400">
              Can't scan it? Enter this key in the app instead:
              <code className="mt-1 block break-all rounded bg-slate-100 px-2 py-1 text-xs dark:bg-slate-800">{stage.secret}</code>
            </p>
            {enable.isError && <Alert tone="error">{errorText(enable.error)}</Alert>}
            <Field label="6-digit code" name="code" inputMode="numeric" autoComplete="one-time-code" maxLength={7} required autoFocus />
            <div className="flex gap-3">
              <Button type="submit" disabled={enable.isPending}>
                {enable.isPending ? 'Checking…' : 'Turn on'}
              </Button>
              <Button type="button" variant="secondary" onClick={() => setStage({ kind: 'idle' })}>
                Cancel
              </Button>
            </div>
          </form>
        </div>
      </Card>
    )
  }

  if (!user.two_factor_enabled) {
    return (
      <Card
        title="Two-factor sign-in"
        description="Ask for a code from an authenticator app (Google Authenticator, 1Password, Authy…) after your password or Google/Microsoft sign-in."
      >
        {setup.isError && (
          <div className="mb-3">
            <Alert tone="error">{errorText(setup.error)}</Alert>
          </div>
        )}
        <Button onClick={() => setup.mutate()} disabled={setup.isPending}>
          Turn on two-factor sign-in
        </Button>
      </Card>
    )
  }

  const pendingAction = action === 'disable' ? disable : regenerate

  return (
    <Card title="Two-factor sign-in" description="Signing in needs a code from your authenticator app.">
      <div className="space-y-4 text-sm">
        <p>
          <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-800 ring-1 ring-inset ring-emerald-200 dark:bg-emerald-950 dark:text-emerald-200 dark:ring-emerald-900">
            On
          </span>{' '}
          <span className="text-slate-600 dark:text-slate-400">
            {user.recovery_codes_remaining} of 10 recovery codes left
            {user.recovery_codes_remaining <= 3 && ' (consider replacing them)'}
          </span>
        </p>
        {action ? (
          <form
            onSubmit={(event: FormEvent<HTMLFormElement>) => {
              event.preventDefault()
              pendingAction.mutate(codeFrom(event))
            }}
            className="max-w-sm space-y-3"
          >
            {pendingAction.isError && <Alert tone="error">{errorText(pendingAction.error)}</Alert>}
            <Field
              label={action === 'disable' ? 'Code from your app or a recovery code' : 'Code from your authenticator app'}
              name="code"
              autoComplete="one-time-code"
              required
              autoFocus
            />
            <div className="flex gap-3">
              <Button type="submit" variant={action === 'disable' ? 'danger' : 'primary'} disabled={pendingAction.isPending}>
                {action === 'disable' ? 'Turn off' : 'Replace codes'}
              </Button>
              <Button type="button" variant="secondary" onClick={() => setAction(null)}>
                Cancel
              </Button>
            </div>
          </form>
        ) : (
          <div className="flex flex-wrap gap-3">
            <Button variant="secondary" onClick={() => setAction('regenerate')}>
              Replace recovery codes
            </Button>
            <Button variant="secondary" onClick={() => setAction('disable')}>
              Turn off
            </Button>
          </div>
        )}
      </div>
    </Card>
  )
}

function RecoveryCodes({ codes, onDone }: { codes: string[]; onDone: () => void }) {
  const download = `data:text/plain;charset=utf-8,${encodeURIComponent(
    `Evidex recovery codes\nEach code works once. Keep them somewhere safe.\n\n${codes.join('\n')}\n`,
  )}`

  return (
    <Card title="Save your recovery codes" description="Use one if you lose your phone. Each works once. They won't be shown again.">
      <ul aria-label="Recovery codes" className="grid max-w-md grid-cols-2 gap-2 font-mono text-sm">
        {codes.map((code) => (
          <li key={code} className="rounded bg-slate-100 px-3 py-1.5 text-center dark:bg-slate-800">
            {code}
          </li>
        ))}
      </ul>
      <div className="mt-4 flex flex-wrap gap-3">
        <a
          href={download}
          download="evidex-recovery-codes.txt"
          className="rounded-md bg-white px-3.5 py-2 text-sm font-semibold shadow-sm ring-1 ring-inset ring-slate-300 hover:bg-slate-50 dark:bg-slate-900 dark:ring-slate-700 dark:hover:bg-slate-800"
        >
          Download as text
        </a>
        <Button onClick={onDone}>I've saved them</Button>
      </div>
    </Card>
  )
}
