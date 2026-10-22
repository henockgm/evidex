import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router'
import { ApiError, api, unwrap, type Session } from '../api/client'
import { oauthErrorMessage } from '../auth/oauthErrors'
import { leaveApp, meQueryKey, useAuthChanged, useMe } from '../auth/useAuth'
import { useProviders } from '../auth/useProviders'
import { OAuthButton } from '../components/OAuthButtons'
import { SudoProvider } from '../security/SudoProvider'
import { TwoFactorCard } from '../security/TwoFactorCard'
import { useSudo } from '../security/sudo'
import { Alert, Button, Card, Field } from '../components/ui'

const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })

export function SecurityPage() {
  const [searchParams] = useSearchParams()
  const linked = searchParams.get('linked')
  const reauthenticated = searchParams.get('reauthenticated')
  const linkError = oauthErrorMessage(searchParams.get('error'))

  return (
    <SudoProvider>
      <div className="space-y-6">
        <h1 className="text-2xl font-bold tracking-tight">Security</h1>
        {linked && <Alert tone="success">Account connected. You can now sign in with it.</Alert>}
        {reauthenticated && <Alert tone="success">Thanks, that's confirmed. You can make your change now.</Alert>}
        {linkError && <Alert tone="error">{linkError}</Alert>}
        <PasswordSection />
        <TwoFactorCard />
        <ConnectedAccountsSection />
        <SessionsSection />
        <DeleteAccountSection />
      </div>
    </SudoProvider>
  )
}

function PasswordSection() {
  const { data: user } = useMe()
  const authChanged = useAuthChanged()
  const withSudo = useSudo()
  const [error, setError] = useState<Error | null>(null)
  const [saved, setSaved] = useState(false)

  const change = useMutation({
    mutationFn: (body: { password: string }) => withSudo(() => unwrap(api.PATCH('/api/v1/me/password', { body }))),
    onSuccess: ({ user: updated }, _variables) => {
      setSaved(true)
      setError(null)
      authChanged(updated)
    },
    onError: setError,
  })

  if (!user) return null
  const fieldErrors = error instanceof ApiError ? error.problem?.errors : undefined

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const formElement = event.currentTarget
    setSaved(false)
    change.mutate({ password: String(new FormData(formElement).get('password')) }, { onSuccess: () => formElement.reset() })
  }

  return (
    <Card
      title={user.has_password ? 'Change password' : 'Add a password'}
      description={
        user.has_password
          ? 'Other devices are signed out when you change your password.'
          : 'You sign in with Google or Microsoft. Adding a password gives you another way in.'
      }
    >
      <form onSubmit={handleSubmit} className="max-w-sm space-y-4">
        {saved && <Alert tone="success">Password saved. Other devices were signed out.</Alert>}
        {error && !fieldErrors && <Alert tone="error">{error.message}</Alert>}
        <Field
          label="New password"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={12}
          required
          hint="At least 12 characters."
          errors={fieldErrors?.password}
        />
        <Button type="submit" disabled={change.isPending}>
          {change.isPending ? 'Saving…' : 'Save password'}
        </Button>
      </form>
    </Card>
  )
}

function ConnectedAccountsSection() {
  const { data: user } = useMe()
  const { data: providers = [] } = useProviders()
  const queryClient = useQueryClient()
  const withSudo = useSudo()

  const disconnect = useMutation({
    mutationFn: (id: number) => withSudo(() => unwrap(api.DELETE('/api/v1/me/identities/{id}', { params: { path: { id } } }))),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: meQueryKey }),
  })

  if (!user) return null
  const connected = new Set(user.identities.map((identity) => identity.provider))
  const onlyMethod = !user.has_password && user.identities.length === 1

  return (
    <Card title="Connected accounts" description="Sign in with Google or Microsoft instead of a password.">
      {disconnect.isError && (
        <div className="mb-4">
          <Alert tone="error">{disconnect.error.message}</Alert>
        </div>
      )}
      <ul className="divide-y divide-slate-200 dark:divide-slate-800">
        {user.identities.map((identity) => (
          <li key={identity.id} className="flex items-center justify-between gap-4 py-3 text-sm">
            <span>
              <span className="font-medium">{identity.label}</span>
              {identity.email && <span className="text-slate-500"> · {identity.email}</span>}
            </span>
            <Button
              variant="secondary"
              disabled={onlyMethod || disconnect.isPending}
              title={onlyMethod ? 'Add a password or another account first' : undefined}
              onClick={() => disconnect.mutate(identity.id)}
            >
              Disconnect
            </Button>
          </li>
        ))}
        {providers
          .filter((provider) => !connected.has(provider.id as 'google_oauth2' | 'entra_id'))
          .map((provider) => (
            <li key={provider.id} className="flex items-center justify-between gap-4 py-3 text-sm">
              <span className="font-medium">{provider.label}</span>
              <div className="w-32">
                <OAuthButton path={provider.path}>Connect</OAuthButton>
              </div>
            </li>
          ))}
      </ul>
      {!providers.length && !user.identities.length && (
        <p className="text-sm text-slate-500">Google and Microsoft sign-in aren't configured on this server.</p>
      )}
    </Card>
  )
}

function describeDevice(session: Session) {
  const agent = session.user_agent ?? 'Unknown device'
  const browser = /Edg\//.test(agent)
    ? 'Edge'
    : /Firefox\//.test(agent)
      ? 'Firefox'
      : /Chrome\//.test(agent)
        ? 'Chrome'
        : /Safari\//.test(agent)
          ? 'Safari'
          : agent.slice(0, 40)
  // Phones first: iOS user agents also say "like Mac OS X", Android ones "Linux".
  const os = /iPhone|iPad/.test(agent)
    ? 'iOS'
    : /Android/.test(agent)
      ? 'Android'
      : /Mac OS X/.test(agent)
        ? 'macOS'
        : /Windows/.test(agent)
          ? 'Windows'
          : /Linux/.test(agent)
            ? 'Linux'
            : null
  return os ? `${browser} on ${os}` : browser
}

function SessionsSection() {
  const queryClient = useQueryClient()
  const sessionsKey = ['me', 'sessions']

  const { data: sessions = [], isPending } = useQuery({
    queryKey: sessionsKey,
    queryFn: async () => (await unwrap(api.GET('/api/v1/me/sessions'))).sessions,
  })

  const revoke = useMutation({
    mutationFn: async (session: Session) => {
      await unwrap(api.DELETE('/api/v1/me/sessions/{id}', { params: { path: { id: session.id } } }))
      return session
    },
    onSuccess: (session) => {
      if (session.current) {
        leaveApp('/login')
      } else {
        void queryClient.invalidateQueries({ queryKey: sessionsKey })
      }
    },
  })

  const revokeOthers = useMutation({
    mutationFn: () => unwrap(api.DELETE('/api/v1/me/sessions/others')),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: sessionsKey }),
  })

  return (
    <Card title="Signed-in devices" description="Sign out anything you don't recognise.">
      {isPending ? (
        <p className="text-sm text-slate-500">Loading…</p>
      ) : (
        <ul className="divide-y divide-slate-200 dark:divide-slate-800">
          {sessions.map((session) => (
            <li key={session.id} className="flex items-center justify-between gap-4 py-3 text-sm">
              <div>
                <p className="font-medium">
                  {describeDevice(session)}
                  {session.current && (
                    <span className="ml-2 rounded bg-emerald-100 px-1.5 py-0.5 text-xs text-emerald-800 dark:bg-emerald-900 dark:text-emerald-100">
                      This device
                    </span>
                  )}
                </p>
                <p className="text-slate-500">
                  {session.ip_address} · last active {dateTime.format(new Date(session.last_active_at))}
                </p>
              </div>
              <Button variant="secondary" onClick={() => revoke.mutate(session)} disabled={revoke.isPending}>
                Sign out
              </Button>
            </li>
          ))}
        </ul>
      )}
      {sessions.length > 1 && (
        <Button variant="secondary" className="mt-4" onClick={() => revokeOthers.mutate()} disabled={revokeOthers.isPending}>
          Sign out all other devices
        </Button>
      )}
    </Card>
  )
}

function DeleteAccountSection() {
  const { data: user } = useMe()
  const withSudo = useSudo()

  const destroy = useMutation({
    mutationFn: (body: { confirm_email: string }) => withSudo(() => unwrap(api.DELETE('/api/v1/me', { body }))),
    onSuccess: () => leaveApp('/register'),
  })

  if (!user) return null
  const error = destroy.error
  const fieldErrors = error instanceof ApiError ? error.fieldErrors('confirm_email') : []

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    destroy.mutate({ confirm_email: String(new FormData(event.currentTarget).get('confirm_email')) })
  }

  return (
    <Card title="Delete account" description="Permanently deletes your account and everything in it. This can't be undone.">
      <form onSubmit={handleSubmit} className="max-w-sm space-y-4">
        {error && !fieldErrors.length && <Alert tone="error">{error.message}</Alert>}
        <Field label={`Type ${user.email_address} to confirm`} name="confirm_email" type="email" required errors={fieldErrors} />
        <Button type="submit" variant="danger" disabled={destroy.isPending}>
          {destroy.isPending ? 'Deleting…' : 'Delete my account'}
        </Button>
      </form>
    </Card>
  )
}
