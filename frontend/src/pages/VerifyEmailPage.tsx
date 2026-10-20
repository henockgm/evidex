import { useEffect, useRef, useState } from 'react'
import { Link, useSearchParams } from 'react-router'
import { ApiError, api, unwrap } from '../api/client'
import { useAuthChanged } from '../auth/useAuth'
import { Alert, AuthCard, Spinner } from '../components/ui'

type State = { kind: 'verifying' } | { kind: 'done'; message: string } | { kind: 'failed'; message: string }

export function VerifyEmailPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const authChanged = useAuthChanged()
  const [state, setState] = useState<State>({ kind: 'verifying' })
  const started = useRef(false)

  useEffect(() => {
    if (started.current) return // StrictMode runs effects twice in development
    started.current = true

    const token = searchParams.get('token') ?? ''
    setSearchParams({}, { replace: true })

    unwrap(api.POST('/api/v1/email_verification', { body: { token } }))
      .then((result) => {
        setState({ kind: 'done', message: result.message })
        authChanged()
      })
      .catch((caught: unknown) =>
        setState({
          kind: 'failed',
          message: caught instanceof ApiError ? (caught.problem?.title ?? caught.message) : 'Something went wrong.',
        }),
      )
  }, [authChanged, searchParams, setSearchParams])

  return (
    <AuthCard title="Confirm your email">
      {state.kind === 'verifying' && <Spinner label="Confirming…" />}
      {state.kind === 'done' && <Alert tone="success">{state.message}</Alert>}
      {state.kind === 'failed' && (
        <Alert tone="error">{state.message}. Sign in and request a new confirmation email.</Alert>
      )}
      {state.kind !== 'verifying' && (
        <Link to="/" className="block text-center text-sm font-semibold text-indigo-600 hover:underline dark:text-indigo-400">
          Continue
        </Link>
      )}
    </AuthCard>
  )
}
