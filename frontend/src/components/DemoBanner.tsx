import { leaveApp, signOut } from '../auth/useAuth'

/** Reminds visitors that the demo account is shared and reset, so nothing personal goes in. */
export function DemoBanner() {
  async function createAccount() {
    try {
      await signOut()
    } finally {
      leaveApp('/register')
    }
  }

  return (
    <div role="status" className="border-b border-amber-200 bg-amber-50 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950/50 dark:text-amber-100">
      <p className="mx-auto max-w-4xl px-4 py-2">
        <strong>Demo:</strong> the data is fictional, shared with other visitors and reset every night, so please don't
        enter anything personal.{' '}
        <button type="button" onClick={createAccount} className="font-semibold underline">
          Create your own account
        </button>
      </p>
    </div>
  )
}
