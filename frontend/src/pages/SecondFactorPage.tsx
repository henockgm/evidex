import { useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { ApiError, api, unwrap } from '../api/client'
import { useAuthChanged } from '../auth/useAuth'
import { Alert, AuthCard, Button, Field } from '../components/ui'

function safeNext(next: string | null) {
  return next?.startsWith('/') && !next.startsWith('//') ? next : '/'
}

/** Second sign-in step for accounts with two-factor sign-in turned on. */
export function SecondFactorPage() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const authChanged = useAuthChanged()
  const [useRecovery, setUseRecovery] = useState(false)
  const [error, setError] = useState<ApiError | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const expired = error?.status === 401

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const code = String(new FormData(event.currentTarget).get('code') ?? '').trim()
    setSubmitting(true)
    setError(null)
    try {
      const { user } = await unwrap(api.POST('/api/v1/session/second_factor', { body: { code } }))
      authChanged(user)
      navigate(safeNext(searchParams.get('next')), { replace: true })
    } catch (caught) {
      setError(caught instanceof ApiError ? caught : new ApiError(0))
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <AuthCard
      title="Two-factor sign-in"
      footer={
        <Link to="/login" className="font-semibold text-indigo-600 hover:underline dark:text-indigo-400">
          Back to sign in
        </Link>
      }
    >
      {error && (
        <Alert tone="error">
          {expired ? `${error.problem?.title ?? 'Sign-in expired'}. ${error.problem?.detail ?? ''}` : (error.problem?.title ?? error.message)}
        </Alert>
      )}
      {!expired && (
        <form onSubmit={handleSubmit} className="space-y-4">
          {useRecovery ? (
            <Field
              key="recovery"
              label="Recovery code"
              name="code"
              autoComplete="off"
              placeholder="xxxxx-xxxxx"
              required
              hint="Each recovery code works once."
            />
          ) : (
            <Field
              key="totp"
              label="Code from your authenticator app"
              name="code"
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9 ]{6,7}"
              maxLength={7}
              required
              autoFocus
            />
          )}
          <Button type="submit" className="w-full" disabled={submitting}>
            {submitting ? 'Checking…' : 'Verify'}
          </Button>
          <button
            type="button"
            onClick={() => setUseRecovery((value) => !value)}
            className="block w-full text-center text-sm text-indigo-600 hover:underline dark:text-indigo-400"
          >
            {useRecovery ? 'Use your authenticator app instead' : 'Use a recovery code'}
          </button>
        </form>
      )}
    </AuthCard>
  )
}
