import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useNavigate } from 'react-router'
import { api, unwrap, type JobPostingInput } from '../api/client'
import { Alert, Card } from '../components/ui'
import { ImportFromLink } from '../postings/ImportFromLink'
import { PostingForm } from '../postings/PostingForm'
import { postingsQueryKey } from '../postings/queries'

interface Imported {
  draft: JobPostingInput
  structured: boolean
  count: number // remounts the form so it picks up each new draft
}

export function NewPostingPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [imported, setImported] = useState<Imported | null>(null)

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

      <Card title="Import from a link" description="Evidex fetches the page and fills in the form below for you to check.">
        <ImportFromLink
          onImported={(draft, structured) =>
            setImported((previous) => ({ draft, structured, count: (previous?.count ?? 0) + 1 }))
          }
        />
      </Card>

      <Card title="Posting details" description="Or paste the job ad's text yourself.">
        {imported && (
          <div className="mb-4">
            <Alert tone={imported.structured ? 'success' : 'info'}>
              {imported.structured
                ? 'Imported the job details the site publishes. Check them before saving.'
                : "This page doesn't publish structured job details, so the fields are a best guess from its text. Check them before saving."}
            </Alert>
          </div>
        )}
        <PostingForm
          key={imported?.count ?? 0}
          initial={imported?.draft}
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
