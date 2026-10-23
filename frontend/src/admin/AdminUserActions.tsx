import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { api, unwrap, type AdminUser } from '../api/client'
import { useMe } from '../auth/useAuth'
import { Alert, Button } from '../components/ui'
import { useSudo } from '../security/sudo'

type Action = 'lock' | 'unlock' | 'sign_out'

const confirmations: Record<Action, { question: string; button: string }> = {
  lock: { question: 'Lock this account? It is signed out everywhere and emailed.', button: 'Lock account' },
  unlock: { question: 'Unlock this account?', button: 'Unlock account' },
  sign_out: { question: 'Sign this account out on every device?', button: 'Sign out everywhere' },
}

/** Lock/unlock and force sign-out for one account; asks first, then "Confirm it's you" if needed. */
export function AdminUserActions({ user }: { user: AdminUser }) {
  const { data: me } = useMe()
  const queryClient = useQueryClient()
  const withSudo = useSudo()
  const [asking, setAsking] = useState<Action | null>(null)

  const run = useMutation({
    mutationFn: (action: Action) => {
      const params = { params: { path: { user_id: user.id } } }
      return withSudo(() =>
        unwrap(
          action === 'lock'
            ? api.POST('/api/v1/admin/users/{user_id}/lock', params)
            : action === 'unlock'
              ? api.DELETE('/api/v1/admin/users/{user_id}/lock', params)
              : api.POST('/api/v1/admin/users/{user_id}/sign_out', params),
        ),
      )
    },
    onSuccess: () => {
      setAsking(null)
      return queryClient.invalidateQueries({ queryKey: ['admin'] })
    },
  })

  if (user.id === me?.id) return null

  const locked = Boolean(user.suspended_at || user.locked_until)

  if (asking) {
    const { question, button } = confirmations[asking]
    return (
      <div className="flex flex-wrap items-center gap-2 pt-1">
        <span className="text-slate-700 dark:text-slate-300">{question}</span>
        <Button variant={asking === 'unlock' ? 'primary' : 'danger'} disabled={run.isPending} onClick={() => run.mutate(asking)}>
          {button}
        </Button>
        <Button variant="secondary" disabled={run.isPending} onClick={() => {
            setAsking(null)
            run.reset()
          }}>
          Cancel
        </Button>
        {run.error && <Alert tone="error">{run.error.message}</Alert>}
      </div>
    )
  }

  return (
    <div className="flex flex-wrap gap-2 pt-1">
      {user.active_sessions > 0 && (
        <Button variant="secondary" onClick={() => setAsking('sign_out')}>
          Sign out everywhere
        </Button>
      )}
      <Button variant="secondary" onClick={() => setAsking(locked ? 'unlock' : 'lock')}>
        {locked ? 'Unlock' : 'Lock'}
      </Button>
    </div>
  )
}
