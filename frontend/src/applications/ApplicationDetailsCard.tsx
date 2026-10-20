import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { ApiError, api, unwrap, type ApplicationLink, type JobApplication, type JobApplicationInput } from '../api/client'
import { Alert, Button, Card, Field, TextArea } from '../components/ui'
import { formatDate } from '../postings/labels'
import { postingQueryKey } from '../postings/queries'

const smallInput =
  'block w-full rounded-md border-0 bg-white px-3 py-1.5 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700'

export function ApplicationDetailsCard({ postingId, application }: { postingId: number; application: JobApplication }) {
  const [editing, setEditing] = useState(false)

  return (
    <Card title="Details" description="When you applied, what to do next, and anything worth remembering.">
      {editing ? (
        <DetailsForm postingId={postingId} application={application} onDone={() => setEditing(false)} />
      ) : (
        <DetailsView application={application} onEdit={() => setEditing(true)} />
      )}
    </Card>
  )
}

function DetailsView({ application, onEdit }: { application: JobApplication; onEdit: () => void }) {
  const empty = !application.applied_on && !application.next_action && !application.notes && !application.links.length

  return (
    <div className="space-y-4 text-sm">
      {empty ? (
        <p className="text-slate-500">No details yet.</p>
      ) : (
        <dl className="grid gap-x-6 gap-y-3 sm:grid-cols-2">
          {application.applied_on && (
            <div>
              <dt className="text-slate-500">Applied on</dt>
              <dd className="font-medium">{formatDate(application.applied_on)}</dd>
            </div>
          )}
          {(application.next_action || application.next_action_on) && (
            <div>
              <dt className="text-slate-500">Next action</dt>
              <dd className="font-medium">
                {application.next_action ?? 'Follow up'}
                {application.next_action_on && <span className="text-slate-500"> · by {formatDate(application.next_action_on)}</span>}
              </dd>
            </div>
          )}
          {application.notes && (
            <div className="sm:col-span-2">
              <dt className="text-slate-500">Notes</dt>
              <dd className="whitespace-pre-wrap">{application.notes}</dd>
            </div>
          )}
          {application.links.length > 0 && (
            <div className="sm:col-span-2">
              <dt className="text-slate-500">Links</dt>
              <dd>
                <ul className="mt-1 space-y-1">
                  {application.links.map((link) => (
                    <li key={link.url}>
                      <a
                        href={link.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="break-all font-medium text-indigo-600 hover:underline dark:text-indigo-400"
                      >
                        {link.label || link.url}
                      </a>
                    </li>
                  ))}
                </ul>
              </dd>
            </div>
          )}
        </dl>
      )}
      <Button variant="secondary" onClick={onEdit}>
        Edit details
      </Button>
    </div>
  )
}

function DetailsForm({ postingId, application, onDone }: { postingId: number; application: JobApplication; onDone: () => void }) {
  const queryClient = useQueryClient()
  const [links, setLinks] = useState<ApplicationLink[]>(application.links.length ? application.links : [])

  const save = useMutation({
    mutationFn: (job_application: JobApplicationInput) =>
      unwrap(api.PATCH('/api/v1/job_applications/{id}', { params: { path: { id: application.id } }, body: { job_application } })),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: postingQueryKey(postingId) })
      onDone()
    },
  })
  const error = save.error instanceof ApiError ? save.error : null

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const value = (name: string) => String(form.get(name) ?? '').trim() || null
    save.mutate({
      applied_on: value('applied_on'),
      next_action: value('next_action'),
      next_action_on: value('next_action_on'),
      notes: value('notes'),
      links: links.filter((link) => link.url.trim() || link.label?.trim()),
    })
  }

  function updateLink(index: number, change: Partial<ApplicationLink>) {
    setLinks((current) => current.map((link, i) => (i === index ? { ...link, ...change } : link)))
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {save.isError && !error?.problem?.errors && <Alert tone="error">{save.error.message}</Alert>}
      <div className="grid gap-4 sm:grid-cols-3">
        <Field label="Applied on" name="applied_on" type="date" defaultValue={application.applied_on ?? ''} errors={error?.fieldErrors('applied_on')} />
        <Field
          label="Next action"
          name="next_action"
          maxLength={200}
          placeholder="e.g. Follow up with the recruiter"
          defaultValue={application.next_action ?? ''}
          errors={error?.fieldErrors('next_action')}
        />
        <Field
          label="Next action by"
          name="next_action_on"
          type="date"
          defaultValue={application.next_action_on ?? ''}
          errors={error?.fieldErrors('next_action_on')}
        />
      </div>
      <TextArea label="Notes" name="notes" rows={5} defaultValue={application.notes ?? ''} errors={error?.fieldErrors('notes')} />

      <fieldset className="space-y-2">
        <legend className="text-sm font-medium">Links</legend>
        {links.map((link, index) => (
          <div key={index} className="flex gap-2">
            <input
              aria-label={`Link ${index + 1} label`}
              placeholder="Label"
              maxLength={100}
              value={link.label ?? ''}
              onChange={(event) => updateLink(index, { label: event.target.value })}
              className={`${smallInput} max-w-[12rem]`}
            />
            <input
              aria-label={`Link ${index + 1} URL`}
              type="url"
              placeholder="https://"
              value={link.url}
              onChange={(event) => updateLink(index, { url: event.target.value })}
              className={smallInput}
            />
            <Button type="button" variant="secondary" onClick={() => setLinks((current) => current.filter((_, i) => i !== index))}>
              Remove
            </Button>
          </div>
        ))}
        {error?.fieldErrors('links').map((message) => (
          <p key={message} className="text-xs text-red-600 dark:text-red-400">
            {message}
          </p>
        ))}
        <Button type="button" variant="secondary" onClick={() => setLinks((current) => [...current, { label: '', url: '' }])}>
          Add link
        </Button>
      </fieldset>

      <div className="flex justify-end gap-3">
        <Button type="button" variant="secondary" onClick={onDone}>
          Cancel
        </Button>
        <Button type="submit" disabled={save.isPending}>
          {save.isPending ? 'Saving…' : 'Save details'}
        </Button>
      </div>
    </form>
  )
}
