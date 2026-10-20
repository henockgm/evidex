import { useMutation, useQueryClient } from '@tanstack/react-query'
import type { FormEvent } from 'react'
import { useNavigate } from 'react-router'
import { ApiError, api, unwrap, type JobPostingInput } from '../api/client'
import { Alert, Button, Card, Field, Select, TextArea } from '../components/ui'
import { workModelLabels } from '../postings/labels'
import { postingsQueryKey } from '../postings/queries'

const workModelOptions = [
  { value: '', label: 'Not specified' },
  ...Object.entries(workModelLabels).map(([value, label]) => ({ value, label })),
]

function text(form: FormData, name: string) {
  return String(form.get(name) ?? '').trim()
}

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
  const error = create.error instanceof ApiError ? create.error : null

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    create.mutate({
      title: text(form, 'title'),
      company: text(form, 'company'),
      location: text(form, 'location') || null,
      work_model: (text(form, 'work_model') || null) as JobPostingInput['work_model'],
      deadline: text(form, 'deadline') || null,
      source_url: text(form, 'source_url') || null,
      description: text(form, 'description'),
    })
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold tracking-tight">Add a job posting</h1>
      <Card title="Posting details" description="Paste the job ad's text. Importing from a link comes next.">
        <form onSubmit={handleSubmit} className="space-y-4">
          {create.error && !error?.problem?.errors && <Alert tone="error">{create.error.message}</Alert>}
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Job title" name="title" required maxLength={200} errors={error?.fieldErrors('title')} />
            <Field label="Company" name="company" required maxLength={200} errors={error?.fieldErrors('company')} />
            <Field label="Location" name="location" maxLength={200} errors={error?.fieldErrors('location')} />
            <Select label="Work model" name="work_model" options={workModelOptions} errors={error?.fieldErrors('work_model')} />
            <Field label="Application deadline" name="deadline" type="date" errors={error?.fieldErrors('deadline')} />
            <Field
              label="Link to the ad"
              name="source_url"
              type="url"
              placeholder="https://"
              errors={error?.fieldErrors('source_url')}
            />
          </div>
          <TextArea
            label="Job ad text"
            name="description"
            required
            rows={14}
            hint="Paste the whole ad: responsibilities, requirements, how to apply."
            errors={error?.fieldErrors('description')}
          />
          <div className="flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={() => navigate('/postings')}>
              Cancel
            </Button>
            <Button type="submit" disabled={create.isPending}>
              {create.isPending ? 'Saving…' : 'Save posting'}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  )
}
