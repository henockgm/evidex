import { useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { ApiError, api, unwrap } from '../api/client'
import { Alert, AuthCard, Button, Field } from '../components/ui'

export function ForgotPasswordPage() {
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    setSubmitting(true)
    setError(null)

    try {
      const result = await unwrap(
        api.POST('/api/v1/password_reset', { body: { email_address: String(form.get('email_address')) } }),
      )
      setMessage(result.message)
    } catch (caught) {
      setError(caught instanceof ApiError ? (caught.problem?.detail ?? caught.message) : 'Something went wrong.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <AuthCard
      title="Reset your password"
      footer={
        <Link to="/login" className="font-semibold text-indigo-600 hover:underline dark:text-indigo-400">
          Back to sign in
        </Link>
      }
    >
      {message ? (
        <Alert tone="success">{message}</Alert>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-4">
          {error && <Alert tone="error">{error}</Alert>}
          <Field label="Email" name="email_address" type="email" autoComplete="email" required />
          <Button type="submit" className="w-full" disabled={submitting}>
            {submitting ? 'Sending…' : 'Send reset link'}
          </Button>
        </form>
      )}
    </AuthCard>
  )
}
