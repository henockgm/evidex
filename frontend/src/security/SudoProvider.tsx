import { useMutation } from '@tanstack/react-query'
import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from 'react'
import { ApiError, api, unwrap } from '../api/client'
import { useMe } from '../auth/useAuth'
import { useProviders } from '../auth/useProviders'
import { OAuthButton } from '../components/OAuthButtons'
import { Alert, Button, Field } from '../components/ui'
import { ReauthenticationCancelled, SudoContext, needsReauthentication, type WithSudo } from './sudo'

interface Pending {
  resolve: () => void
  reject: (error: Error) => void
}

/**
 * "Sudo mode" for the security settings: when the API refuses a sensitive change
 * because the last sign-in is too old, shows a dialog to confirm it's the user,
 * then retries the change.
 */
export function SudoProvider({ children }: { children: ReactNode }) {
  // Requests waiting for the user to confirm; one dialog answers all of them.
  const [pending, setPending] = useState<Pending[]>([])

  const withSudo = useCallback<WithSudo>(async (request) => {
    try {
      return await request()
    } catch (error) {
      if (!needsReauthentication(error)) throw error
      await new Promise<void>((resolve, reject) => setPending((waiting) => [...waiting, { resolve, reject }]))
      return request()
    }
  }, [])

  return (
    <SudoContext.Provider value={withSudo}>
      {children}
      {pending.length > 0 && (
        <ReauthDialog
          onConfirmed={() => {
            pending.forEach((waiting) => waiting.resolve())
            setPending([])
          }}
          onCancel={() => {
            pending.forEach((waiting) => waiting.reject(new ReauthenticationCancelled()))
            setPending([])
          }}
        />
      )}
    </SudoContext.Provider>
  )
}

function ReauthDialog({ onConfirmed, onCancel }: { onConfirmed: () => void; onCancel: () => void }) {
  const { data: user } = useMe()
  const { data: providers = [] } = useProviders()
  const [error, setError] = useState<ApiError | null>(null)

  const confirm = useMutation({
    mutationFn: (body: { password?: string; code?: string }) => unwrap(api.POST('/api/v1/me/reauthentication', { body })),
    onSuccess: onConfirmed,
    onError: (caught) => setError(caught instanceof ApiError ? caught : new ApiError(0)),
  })

  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => event.key === 'Escape' && onCancel()
    document.addEventListener('keydown', closeOnEscape)
    return () => document.removeEventListener('keydown', closeOnEscape)
  }, [onCancel])

  if (!user) return null
  const canConfirmHere = user.has_password || user.two_factor_enabled
  const connected = providers.filter((provider) => user.identities.some((identity) => identity.provider === provider.id))

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    setError(null)
    confirm.mutate({
      password: user?.has_password ? String(form.get('password')) : undefined,
      code: user?.two_factor_enabled ? String(form.get('code')).trim() : undefined,
    })
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="reauth-title"
        className="w-full max-w-sm rounded-lg bg-white p-6 shadow-xl ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800"
      >
        <h2 id="reauth-title" className="text-base font-semibold">
          Confirm it's you
        </h2>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          For your security, sensitive changes need a recent sign-in. You won't be asked again for 10 minutes.
        </p>
        {canConfirmHere ? (
          <form onSubmit={handleSubmit} className="mt-4 space-y-4">
            {error && !error.problem?.errors && <Alert tone="error">{error.problem?.detail ?? error.message}</Alert>}
            {user.has_password && (
              <Field
                label="Password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                autoFocus
                errors={error?.fieldErrors('password')}
              />
            )}
            {user.two_factor_enabled && (
              <Field
                label="Code from your app or a recovery code"
                name="code"
                autoComplete="one-time-code"
                required
                autoFocus={!user.has_password}
                errors={error?.fieldErrors('code')}
              />
            )}
            <div className="flex gap-3">
              <Button type="submit" disabled={confirm.isPending}>
                {confirm.isPending ? 'Checking…' : 'Confirm'}
              </Button>
              <Button type="button" variant="secondary" onClick={onCancel}>
                Cancel
              </Button>
            </div>
          </form>
        ) : (
          // Leaves the page for the provider; it comes back to the security page,
          // where the user makes the change again.
          <div className="mt-4 space-y-3">
            {connected.map((provider) => (
              <OAuthButton key={provider.id} path={provider.reauthenticate_path}>
                Continue with {provider.label}
              </OAuthButton>
            ))}
            <Button type="button" variant="secondary" className="w-full" onClick={onCancel}>
              Cancel
            </Button>
          </div>
        )}
      </div>
    </div>
  )
}
