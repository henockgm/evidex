import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { ApiError, api, unwrap, type Interview } from '../api/client'
import { Alert, Button, Card, Field, Select, TextArea } from '../components/ui'
import { postingListsQueryKey, postingQueryKey } from '../postings/queries'

type InterviewInput = Partial<Omit<Interview, 'id'>>
type InterviewFormValues = InterviewInput & { scheduled_at: string }

const formatLabels: Record<NonNullable<Interview['format']>, string> = {
  video: 'Video call',
  phone: 'Phone',
  onsite: 'On-site',
  other: 'Other',
}
const statusTone: Record<Interview['status'], string> = {
  scheduled: 'bg-amber-50 text-amber-800 ring-amber-200 dark:bg-amber-950 dark:text-amber-200 dark:ring-amber-900',
  completed: 'bg-emerald-50 text-emerald-800 ring-emerald-200 dark:bg-emerald-950 dark:text-emerald-200 dark:ring-emerald-900',
  cancelled: 'bg-zinc-100 text-zinc-600 ring-zinc-200 dark:bg-zinc-800 dark:text-zinc-300 dark:ring-zinc-700',
}
const statusLabel: Record<Interview['status'], string> = { scheduled: 'Scheduled', completed: 'Done', cancelled: 'Cancelled' }

const when = new Intl.DateTimeFormat(undefined, { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })

/** "2026-10-28T11:00:00Z" -> "2026-10-28T14:00" in the browser's time zone, for <input type="datetime-local">. */
function toLocalInput(iso: string) {
  const date = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function isLink(value: string) {
  return /^https?:\/\//i.test(value)
}

export function InterviewsCard({
  postingId,
  applicationId,
  interviews,
}: {
  postingId: number
  applicationId: number
  interviews: Interview[]
}) {
  const queryClient = useQueryClient()
  const [adding, setAdding] = useState(false)
  const [editingId, setEditingId] = useState<number | null>(null)
  const refresh = async () => {
    await queryClient.invalidateQueries({ queryKey: postingQueryKey(postingId) })
    void queryClient.invalidateQueries({ queryKey: postingListsQueryKey })
  }

  const add = useMutation({
    mutationFn: (interview: InterviewFormValues) =>
      unwrap(api.POST('/api/v1/job_applications/{job_application_id}/interviews', {
        params: { path: { job_application_id: applicationId } },
        body: { interview },
      })),
    onSuccess: async () => {
      await refresh()
      setAdding(false)
    },
  })
  const update = useMutation({
    mutationFn: ({ id, interview }: { id: number; interview: InterviewInput }) =>
      unwrap(api.PATCH('/api/v1/interviews/{id}', { params: { path: { id } }, body: { interview } })),
    onSuccess: async () => {
      await refresh()
      setEditingId(null)
    },
  })
  const remove = useMutation({
    mutationFn: (id: number) => unwrap(api.DELETE('/api/v1/interviews/{id}', { params: { path: { id } } })),
    onSuccess: refresh,
  })

  return (
    <Card title="Interviews" description="Each round, when it is, and how it went. Adding one moves the application to Interviewing.">
      {(update.isError || remove.isError) && (
        <div className="mb-4">
          <Alert tone="error">{(update.error ?? remove.error)?.message}</Alert>
        </div>
      )}
      {interviews.length === 0 && !adding && <p className="text-sm text-slate-500">No interviews yet.</p>}

      <ul className="divide-y divide-slate-200 dark:divide-slate-800">
        {interviews.map((interview) =>
          editingId === interview.id ? (
            <li key={interview.id} className="py-4">
              <InterviewForm
                initial={interview}
                submitLabel="Save interview"
                pending={update.isPending}
                error={update.error}
                onSubmit={(input) => update.mutate({ id: interview.id, interview: input })}
                onCancel={() => setEditingId(null)}
              />
            </li>
          ) : (
            <li key={interview.id} className="flex flex-wrap items-start justify-between gap-3 py-3 text-sm">
              <div className="space-y-0.5">
                <p className="flex flex-wrap items-center gap-2">
                  <span className="font-medium">{when.format(new Date(interview.scheduled_at))}</span>
                  <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ring-1 ring-inset ${statusTone[interview.status]}`}>
                    {statusLabel[interview.status]}
                  </span>
                </p>
                <p className="text-slate-600 dark:text-slate-400">
                  {[interview.round, interview.format && formatLabels[interview.format]].filter(Boolean).join(' · ')}
                </p>
                {interview.location &&
                  (isLink(interview.location) ? (
                    <a
                      href={interview.location}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="break-all text-indigo-600 hover:underline dark:text-indigo-400"
                    >
                      Join link
                    </a>
                  ) : (
                    <p>{interview.location}</p>
                  ))}
                {interview.notes && <p className="whitespace-pre-wrap text-slate-600 dark:text-slate-400">{interview.notes}</p>}
              </div>
              <div className="flex flex-wrap gap-2">
                {interview.status === 'scheduled' && (
                  <Button
                    variant="secondary"
                    disabled={update.isPending}
                    onClick={() => update.mutate({ id: interview.id, interview: { status: 'completed' } })}
                  >
                    Mark done
                  </Button>
                )}
                <Button variant="secondary" onClick={() => setEditingId(interview.id)} aria-label={`Edit interview on ${when.format(new Date(interview.scheduled_at))}`}>
                  Edit
                </Button>
                <Button
                  variant="secondary"
                  disabled={remove.isPending}
                  onClick={() => remove.mutate(interview.id)}
                  aria-label={`Remove interview on ${when.format(new Date(interview.scheduled_at))}`}
                >
                  Remove
                </Button>
              </div>
            </li>
          ),
        )}
      </ul>

      {adding ? (
        <div className="mt-4">
          <InterviewForm
            submitLabel="Add interview"
            pending={add.isPending}
            error={add.error}
            onSubmit={(input) => add.mutate(input)}
            onCancel={() => setAdding(false)}
          />
        </div>
      ) : (
        <Button variant="secondary" className="mt-4" onClick={() => setAdding(true)}>
          Add interview
        </Button>
      )}
    </Card>
  )
}

function InterviewForm({
  initial,
  submitLabel,
  pending,
  error,
  onSubmit,
  onCancel,
}: {
  initial?: Interview
  submitLabel: string
  pending: boolean
  error: Error | null
  onSubmit: (input: InterviewFormValues) => void
  onCancel: () => void
}) {
  const apiError = error instanceof ApiError ? error : null

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const value = (name: string) => String(form.get(name) ?? '').trim() || null
    const local = value('scheduled_at')
    onSubmit({
      round: value('round'),
      // datetime-local has no time zone: interpret it in the browser's zone and send UTC.
      scheduled_at: local ? new Date(local).toISOString() : '',
      format: value('format') as Interview['format'],
      location: value('location'),
      notes: value('notes'),
      ...(initial ? { status: value('status') as Interview['status'] } : {}),
    })
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && !apiError?.problem?.errors && <Alert tone="error">{error.message}</Alert>}
      <div className="grid gap-4 sm:grid-cols-2">
        <Field
          label="Date and time"
          name="scheduled_at"
          type="datetime-local"
          required
          defaultValue={initial ? toLocalInput(initial.scheduled_at) : ''}
          errors={apiError?.fieldErrors('scheduled_at')}
        />
        <Field
          label="Round"
          name="round"
          maxLength={100}
          placeholder="e.g. 1st round, Technical"
          defaultValue={initial?.round ?? ''}
          errors={apiError?.fieldErrors('round')}
        />
        <Select
          label="Format"
          name="format"
          defaultValue={initial?.format ?? ''}
          options={[{ value: '', label: 'Not specified' }, ...Object.entries(formatLabels).map(([value, label]) => ({ value, label }))]}
          errors={apiError?.fieldErrors('format')}
        />
        <Field
          label="Location or meeting link"
          name="location"
          maxLength={500}
          defaultValue={initial?.location ?? ''}
          errors={apiError?.fieldErrors('location')}
        />
        {initial && (
          <Select
            label="Status"
            name="status"
            defaultValue={initial.status}
            options={(Object.keys(statusLabel) as Interview['status'][]).map((value) => ({ value, label: statusLabel[value] }))}
          />
        )}
      </div>
      <TextArea
        label="Notes"
        name="notes"
        rows={3}
        maxLength={5000}
        placeholder="Who you met, what they asked, how it went"
        defaultValue={initial?.notes ?? ''}
      />
      <div className="flex justify-end gap-3">
        <Button type="button" variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="submit" disabled={pending}>
          {pending ? 'Saving…' : submitLabel}
        </Button>
      </div>
    </form>
  )
}
