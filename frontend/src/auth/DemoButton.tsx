import { useMutation, useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router'
import { api, unwrap } from '../api/client'
import { Alert, Button } from '../components/ui'
import { useAuthChanged } from './useAuth'

/** "Try the demo" on the sign-in page, shown when the server has a demo account. */
export function DemoButton() {
  const navigate = useNavigate()
  const authChanged = useAuthChanged()
  const availability = useQuery({
    queryKey: ['demo-session'],
    queryFn: () => unwrap(api.GET('/api/v1/demo_session')),
    staleTime: Infinity,
  })
  const start = useMutation({
    mutationFn: () => unwrap(api.POST('/api/v1/demo_session')),
    onSuccess: ({ user }) => {
      authChanged(user)
      navigate('/', { replace: true })
    },
  })

  if (!availability.data?.available) return null

  return (
    <div className="mt-6 space-y-2 border-t border-slate-200 pt-6 text-center dark:border-slate-800">
      {start.isError && <Alert tone="error">{start.error.message}</Alert>}
      <Button type="button" variant="secondary" className="w-full" disabled={start.isPending} onClick={() => start.mutate()}>
        {start.isPending ? 'Opening the demo…' : 'Try the demo, no sign-up'}
      </Button>
      <p className="text-xs text-slate-500 dark:text-slate-400">
        Explore Evidex with a fictional job seeker's data. Shared with other visitors and reset every night.
      </p>
    </div>
  )
}
