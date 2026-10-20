import { useEffect, useState, type FormEvent } from 'react'
import { Link, useSearchParams } from 'react-router'
import { ApiError, api, unwrap } from '../api/client'
import { Alert, AuthCard, Button, Field } from '../components/ui'

export function ResetPasswordPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  // Keep the token in memory and drop it from the address bar (and history).
  const [token] = useState(() => searchParams.get('token') ?? '')
  const [error, setError] = useState<ApiError | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (searchParams.has('token')) setSearchParams({}, { replace: true })
  }, [searchParams, setSearchParams])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    setSubmitting(true)
    setError(null)

    try {
      const result = await unwrap(
        api.PATCH('/api/v1/password_reset', { body: { token, password: String(form.get('password')) } }),
      )
      setMessage(result.message)
    } catch (caught) {
      setError(caught instanceof ApiError ? caught : new ApiError(0))
    } finally {
      setSubmitting(false)
    }
  }

  if (message) {
    return (
      <AuthCard title="Password reset">
        <Alert tone="success">{message}</Alert>
        <Link to="/login" className="block text-center text-sm font-semibold text-indigo-600 hover:underline dark:text-indigo-400">
          Sign in
        </Link>
      </AuthCard>
    )
  }

  return (
    <AuthCard title="Choose a new password">
      {!token && <Alert tone="error">This link is missing its token. Request a new reset email.</Alert>}
      {error && !error.problem?.errors && (
        <Alert tone="error">
          {error.problem?.title ?? error.message}.{' '}
          <Link to="/forgot-password" className="font-semibold underline">
            Request a new link
          </Link>
        </Alert>
      )}
      <form onSubmit={handleSubmit} className="space-y-4">
        <Field
          label="New password"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={12}
          required
          hint="At least 12 characters."
          errors={error?.fieldErrors('password')}
        />
        <Button type="submit" className="w-full" disabled={submitting || !token}>
          {submitting ? 'Saving…' : 'Set new password'}
        </Button>
      </form>
    </AuthCard>
  )
}
