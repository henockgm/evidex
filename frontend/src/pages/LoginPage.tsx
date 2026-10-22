import { useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { ApiError, api, resetCsrfToken, unwrap } from '../api/client'
import { oauthErrorMessage } from '../auth/oauthErrors'
import { useAuthChanged } from '../auth/useAuth'
import { OAuthButtons } from '../components/OAuthButtons'
import { Alert, AuthCard, Button, Field } from '../components/ui'

// Only same-site paths, so ?next= can't redirect to another origin.
function safeNext(next: string | null) {
  return next?.startsWith('/') && !next.startsWith('//') ? next : '/'
}

export function LoginPage() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const authChanged = useAuthChanged()
  const [error, setError] = useState<string | null>(oauthErrorMessage(searchParams.get('error')))
  const [submitting, setSubmitting] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    setSubmitting(true)
    setError(null)

    try {
      const result = await unwrap(
        api.POST('/api/v1/session', {
          body: { email_address: String(form.get('email_address')), password: String(form.get('password')) },
        }),
      )
      if ('second_factor_required' in result) {
        // Rails replaced its session (and CSRF token) for the half-finished sign-in.
        resetCsrfToken()
        const next = searchParams.get('next')
        navigate(next ? `/login/verify?next=${encodeURIComponent(next)}` : '/login/verify')
        return
      }
      authChanged(result.user)
      navigate(safeNext(searchParams.get('next')), { replace: true })
    } catch (caught) {
      setError(caught instanceof ApiError ? (caught.problem?.title ?? caught.message) : 'Something went wrong.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <AuthCard
      title="Sign in to Evidex"
      footer={
        <>
          New here?{' '}
          <Link to="/register" className="font-semibold text-indigo-600 hover:underline dark:text-indigo-400">
            Create an account
          </Link>
        </>
      }
    >
      {error && <Alert tone="error">{error}</Alert>}
      <form onSubmit={handleSubmit} className="space-y-4">
        <Field label="Email" name="email_address" type="email" autoComplete="email" required />
        <Field label="Password" name="password" type="password" autoComplete="current-password" required />
        <div className="flex justify-end text-sm">
          <Link to="/forgot-password" className="text-indigo-600 hover:underline dark:text-indigo-400">
            Forgot password?
          </Link>
        </div>
        <Button type="submit" className="w-full" disabled={submitting}>
          {submitting ? 'Signing in…' : 'Sign in'}
        </Button>
      </form>
      <OAuthButtons verb="Sign in" />
    </AuthCard>
  )
}
