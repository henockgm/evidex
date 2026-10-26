import { useMutation } from '@tanstack/react-query'
import type { FormEvent } from 'react'
import { api, unwrap, type JobPostingInput, type JobPostingSummary } from '../api/client'
import { Alert, Button } from '../components/ui'

interface Props {
  onImported: (draft: JobPostingInput, structured: boolean, duplicates: JobPostingSummary[]) => void
}

export function ImportFromLink({ onImported }: Props) {
  const fetchPage = useMutation({
    mutationFn: (url: string) => unwrap(api.POST('/api/v1/job_posting_import', { body: { url } })),
    onSuccess: ({ draft, structured_data, possible_duplicates }) => onImported(draft, structured_data, possible_duplicates),
  })

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const url = String(new FormData(event.currentTarget).get('url') ?? '').trim()
    if (url) fetchPage.mutate(url)
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <div className="flex gap-2">
        <input
          name="url"
          type="url"
          required
          aria-label="Link to the job ad"
          placeholder="https://"
          className="block w-full rounded-md border-0 bg-white px-3 py-2 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700"
        />
        <Button type="submit" disabled={fetchPage.isPending}>
          {fetchPage.isPending ? 'Fetching…' : 'Fetch'}
        </Button>
      </div>
      {fetchPage.isError && (
        <Alert tone="error">
          {fetchPage.error.message} If the site needs a login (LinkedIn, for example), paste the ad's text below instead.
        </Alert>
      )}
    </form>
  )
}
