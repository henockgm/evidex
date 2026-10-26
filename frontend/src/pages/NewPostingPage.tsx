import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useNavigate } from 'react-router'
import { ApiError, api, unwrap, type DuplicatePostingProblem, type JobPostingInput, type JobPostingSummary } from '../api/client'
import { Alert, Card } from '../components/ui'
import { ImportFromLink } from '../postings/ImportFromLink'
import { PostingForm } from '../postings/PostingForm'
import { postingListsQueryKey } from '../postings/queries'

interface Imported {
  draft: JobPostingInput
  structured: boolean
  duplicates: JobPostingSummary[]
  count: number // remounts the form so it picks up each new draft
}

export function NewPostingPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [imported, setImported] = useState<Imported | null>(null)

  const create = useMutation({
    mutationFn: ({ job_posting, confirm_duplicate }: { job_posting: JobPostingInput; confirm_duplicate: boolean }) =>
      unwrap(api.POST('/api/v1/job_postings', { body: { job_posting, confirm_duplicate } })),
    onSuccess: ({ job_posting }) => {
      void queryClient.invalidateQueries({ queryKey: postingListsQueryKey })
      navigate(`/postings/${job_posting.id}`)
    },
  })

  // A 409 lists the postings already saved for this ad; until then, show what the import found.
  const duplicates = duplicatesIn(create.error) ?? imported?.duplicates

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold tracking-tight">Add a job posting</h1>

      <Card title="Import from a link" description="Evidex fetches the page and fills in the form below for you to check.">
        <ImportFromLink
          onImported={(draft, structured, duplicates) =>
            setImported((previous) => ({ draft, structured, duplicates, count: (previous?.count ?? 0) + 1 }))
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
          duplicates={duplicates}
          submitLabel="Save posting"
          pending={create.isPending}
          error={duplicatesIn(create.error) ? null : create.error}
          onSubmit={(job_posting, { confirmDuplicate }) => create.mutate({ job_posting, confirm_duplicate: confirmDuplicate })}
          onCancel={() => navigate('/postings')}
        />
      </Card>
    </div>
  )
}

function duplicatesIn(error: Error | null) {
  if (!(error instanceof ApiError) || error.status !== 409) return undefined
  return (error.problem as DuplicatePostingProblem | undefined)?.possible_duplicates
}
