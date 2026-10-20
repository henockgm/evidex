import { useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { ApiError, api, unwrap } from '../api/client'
import { OAuthButtons } from '../components/OAuthButtons'
import { Alert, AuthCard, Button, Field } from '../components/ui'

export function RegisterPage() {
  const [error, setError] = useState<ApiError | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    setSubmitting(true)
    setError(null)

    try {
      const result = await unwrap(
        api.POST('/api/v1/registration', {
          body: {
            name: String(form.get('name')),
            email_address: String(form.get('email_address')),
            password: String(form.get('password')),
          },
        }),
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
      <AuthCard title="Check your inbox">
        <Alert tone="success">{message}</Alert>
        <Link to="/login" className="block text-center text-sm font-semibold text-indigo-600 hover:underline dark:text-indigo-400">
          Go to sign in
        </Link>
      </AuthCard>
    )
  }

  return (
    <AuthCard
      title="Create your account"
      footer={
        <>
          Already have an account?{' '}
          <Link to="/login" className="font-semibold text-indigo-600 hover:underline dark:text-indigo-400">
            Sign in
          </Link>
        </>
      }
    >
      {error && !error.problem?.errors && <Alert tone="error">{error.problem?.title ?? error.message}</Alert>}
      <form onSubmit={handleSubmit} className="space-y-4">
        <Field label="Name" name="name" autoComplete="name" maxLength={100} errors={error?.fieldErrors('name')} />
        <Field
          label="Email"
          name="email_address"
          type="email"
          autoComplete="email"
          required
          errors={error?.fieldErrors('email_address')}
        />
        <Field
          label="Password"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={12}
          required
          hint="At least 12 characters. A few random words work well."
          errors={error?.fieldErrors('password')}
        />
        <Button type="submit" className="w-full" disabled={submitting}>
          {submitting ? 'Creating account…' : 'Create account'}
        </Button>
      </form>
      <OAuthButtons verb="Sign up" />
    </AuthCard>
  )
}
