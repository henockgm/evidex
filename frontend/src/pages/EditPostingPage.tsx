import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams } from 'react-router'
import { api, unwrap, type JobPostingInput } from '../api/client'
import { Alert, Card, Spinner } from '../components/ui'
import { PostingForm } from '../postings/PostingForm'
import { postingListsQueryKey, postingQueryKey } from '../postings/queries'
import { usePosting } from '../postings/usePosting'

export function EditPostingPage() {
  const id = Number(useParams().id)
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { data: posting, isPending, error } = usePosting(id)

  const update = useMutation({
    mutationFn: (job_posting: JobPostingInput) =>
      unwrap(api.PATCH('/api/v1/job_postings/{id}', { params: { path: { id } }, body: { job_posting } })),
    onSuccess: ({ job_posting }) => {
      queryClient.setQueryData(postingQueryKey(id), job_posting)
      void queryClient.invalidateQueries({ queryKey: postingListsQueryKey })
      navigate(`/postings/${id}`)
    },
  })

  if (isPending) return <Spinner />
  if (error || !posting) return <Alert tone="error">{error?.message ?? 'Posting not found.'}</Alert>

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold tracking-tight">Edit posting</h1>
      <Card title={posting.title}>
        <PostingForm
          initial={posting}
          submitLabel="Save changes"
          pending={update.isPending}
          error={update.error}
          onSubmit={(input) => update.mutate(input)}
          onCancel={() => navigate(`/postings/${id}`)}
        />
      </Card>
    </div>
  )
}
