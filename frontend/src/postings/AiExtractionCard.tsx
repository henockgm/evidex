import { useMutation, useQueryClient } from '@tanstack/react-query'
import type { JobPosting } from '../api/client'
import { api, unwrap } from '../api/client'
import { useMe } from '../auth/useAuth'
import { Alert, Button, Card } from '../components/ui'
import { postingQueryKey } from './queries'

const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })

/** Starts AI extraction; the posting page polls while extraction.status is "pending". */
export function AiExtractionCard({ posting }: { posting: JobPosting }) {
  const { data: user } = useMe()
  const queryClient = useQueryClient()
  const { status, error, extracted_at } = posting.extraction

  const start = useMutation({
    mutationFn: () =>
      unwrap(api.POST('/api/v1/job_postings/{job_posting_id}/extraction', { params: { path: { job_posting_id: posting.id } } })),
    onSuccess: ({ job_posting }) => queryClient.setQueryData(postingQueryKey(posting.id), job_posting),
  })

  if (!user?.ai_configured) return null

  const pending = status === 'pending' || start.isPending
  const blockedReason = !user.email_verified ? 'Confirm your email address to use AI features.' : null

  return (
    <Card
      title="Read the ad with AI"
      description="Claude fills in empty fields and adds the requirements it finds. It never overwrites what you entered."
    >
      <div className="space-y-3">
        {status === 'done' && extracted_at && !pending && (
          <Alert tone="success">
            Read on {dateTime.format(new Date(extracted_at))}. Check the details and requirements below.
          </Alert>
        )}
        {status === 'failed' && !pending && <Alert tone="error">{error ?? 'The AI could not read this posting.'}</Alert>}
        {start.isError && <Alert tone="error">{start.error.message}</Alert>}
        {blockedReason && <p className="text-sm text-slate-500">{blockedReason}</p>}

        <div className="flex items-center gap-3">
          <Button onClick={() => start.mutate()} disabled={pending || Boolean(blockedReason)}>
            {pending ? 'Reading the ad…' : status === 'done' ? 'Read again' : 'Read with AI'}
          </Button>
          {pending && (
            <span role="status" className="text-sm text-slate-500">
              This usually takes a few seconds.
            </span>
          )}
        </div>
      </div>
    </Card>
  )
}
