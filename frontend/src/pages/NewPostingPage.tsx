import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router'
import { api, unwrap, type JobPostingInput } from '../api/client'
import { Card } from '../components/ui'
import { PostingForm } from '../postings/PostingForm'
import { postingsQueryKey } from '../postings/queries'

export function NewPostingPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const create = useMutation({
    mutationFn: (job_posting: JobPostingInput) => unwrap(api.POST('/api/v1/job_postings', { body: { job_posting } })),
    onSuccess: ({ job_posting }) => {
      void queryClient.invalidateQueries({ queryKey: postingsQueryKey })
      navigate(`/postings/${job_posting.id}`)
    },
  })

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold tracking-tight">Add a job posting</h1>
      <Card title="Posting details" description="Paste the job ad's text. Importing from a link comes next.">
        <PostingForm
          submitLabel="Save posting"
          pending={create.isPending}
          error={create.error}
          onSubmit={(input) => create.mutate(input)}
          onCancel={() => navigate('/postings')}
        />
      </Card>
    </div>
  )
}
