import { useMutation } from '@tanstack/react-query'
import { api, unwrap } from '../api/client'
import { useMe } from '../auth/useAuth'
import { Alert, Button, Card } from '../components/ui'

export function DashboardPage() {
  const { data: user } = useMe()
  const resend = useMutation({ mutationFn: () => unwrap(api.POST('/api/v1/email_verification/resend')) })

  if (!user) return null

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold tracking-tight">Welcome{user.name ? `, ${user.name}` : ''}</h1>

      {!user.email_verified && (
        <Alert tone="info">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <span>Confirm {user.email_address} to unlock the AI features.</span>
            {resend.isSuccess ? (
              <span className="font-medium">{resend.data.message}</span>
            ) : (
              <Button variant="secondary" onClick={() => resend.mutate()} disabled={resend.isPending}>
                Resend email
              </Button>
            )}
          </div>
          {resend.isError && <p className="mt-2">{resend.error.message}</p>}
        </Alert>
      )}

      <Card title="Job postings" description="Coming in milestone M2: import postings and track applications.">
        <p className="text-sm text-slate-500">Nothing here yet.</p>
      </Card>
    </div>
  )
}
