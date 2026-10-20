import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { ApiError, api, unwrap, type ApplicationStatus, type JobApplication } from '../api/client'
import { Alert, Button, Card } from '../components/ui'
import { postingListsQueryKey, postingQueryKey } from '../postings/queries'
import { StatusBadge } from './StatusBadge'
import { statusLabels, transitionLabels } from './labels'

const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })

export function ApplicationCard({ postingId, application }: { postingId: number; application: JobApplication }) {
  const queryClient = useQueryClient()
  const [note, setNote] = useState('')

  const move = useMutation({
    mutationFn: (to_status: ApplicationStatus) =>
      unwrap(
        api.POST('/api/v1/job_applications/{id}/transitions', {
          params: { path: { id: application.id } },
          body: { to_status, note: note.trim() || undefined },
        }),
      ),
    onSuccess: () => {
      setNote('')
      void queryClient.invalidateQueries({ queryKey: postingQueryKey(postingId) })
      void queryClient.invalidateQueries({ queryKey: postingListsQueryKey })
    },
  })
  const error = move.error instanceof ApiError ? (move.error.problem?.detail ?? Object.values(move.error.problem?.errors ?? {}).flat()[0]) : null

  return (
    <Card title="Application">
      <div className="flex flex-wrap items-center gap-3 text-sm">
        <span className="text-slate-500">Status</span>
        <StatusBadge status={application.status} />
      </div>

      {application.available_transitions.length > 0 ? (
        <div className="mt-4 space-y-3">
          <label className="block text-sm font-medium" htmlFor="status-note">
            Note for the timeline <span className="font-normal text-slate-500">(optional)</span>
          </label>
          <textarea
            id="status-note"
            rows={2}
            maxLength={2000}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="e.g. Applied through their careers page"
            className="block w-full rounded-md border-0 bg-white px-3 py-2 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700"
          />
          <div className="flex flex-wrap gap-2">
            {application.available_transitions.map((status) => (
              <Button
                key={status}
                variant={status === 'withdrawn' || status === 'rejected' || status === 'saved' ? 'secondary' : 'primary'}
                disabled={move.isPending}
                onClick={() => move.mutate(status)}
              >
                {transitionLabels[status]}
              </Button>
            ))}
          </div>
          {move.isError && <Alert tone="error">{error ?? move.error.message}</Alert>}
        </div>
      ) : (
        <p className="mt-3 text-sm text-slate-500">This application is closed.</p>
      )}

      <h3 id={`timeline-${application.id}`} className="mt-6 text-sm font-semibold">
        Timeline
      </h3>
      <ol aria-labelledby={`timeline-${application.id}`} className="mt-2 space-y-3 border-l border-slate-200 pl-4 dark:border-slate-800">
        {[...application.events].reverse().map((event) => (
          <li key={event.id} className="relative text-sm">
            <span className="absolute -left-[21px] top-1.5 h-2.5 w-2.5 rounded-full bg-indigo-500 ring-4 ring-white dark:ring-slate-900" />
            <p>
              {event.from_status ? (
                <>
                  {statusLabels[event.from_status]} → <span className="font-medium">{statusLabels[event.to_status]}</span>
                </>
              ) : (
                <span className="font-medium">Saved the posting</span>
              )}
              <span className="ml-2 text-slate-500">{dateTime.format(new Date(event.created_at))}</span>
            </p>
            {event.note && <p className="mt-0.5 whitespace-pre-wrap text-slate-600 dark:text-slate-400">{event.note}</p>}
          </li>
        ))}
      </ol>
    </Card>
  )
}
