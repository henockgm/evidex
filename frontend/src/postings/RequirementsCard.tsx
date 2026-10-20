import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { ApiError, api, unwrap, type Requirement } from '../api/client'
import { Alert, Button, Card } from '../components/ui'
import { postingQueryKey } from './queries'

const groups: { kind: Requirement['kind']; title: string; placeholder: string }[] = [
  { kind: 'required', title: 'Required qualifications', placeholder: 'e.g. 3+ years with Ruby on Rails' },
  { kind: 'preferred', title: 'Nice to have', placeholder: 'e.g. Experience with pgvector' },
  { kind: 'responsibility', title: 'Responsibilities', placeholder: 'e.g. Design and build REST APIs' },
]

const inputClass =
  'block w-full rounded-md border-0 bg-white px-3 py-1.5 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700'
const linkButton = 'text-xs font-medium text-slate-500 hover:text-slate-900 hover:underline dark:hover:text-slate-100'

export function RequirementsCard({ postingId, requirements }: { postingId: number; requirements: Requirement[] }) {
  const queryClient = useQueryClient()
  const refresh = () => queryClient.invalidateQueries({ queryKey: postingQueryKey(postingId) })
  const [error, setError] = useState<string | null>(null)
  const onError = (caught: Error) =>
    setError(caught instanceof ApiError ? Object.values(caught.problem?.errors ?? {}).flat()[0] ?? caught.message : caught.message)

  const add = useMutation({
    mutationFn: (requirement: { kind: Requirement['kind']; text: string }) =>
      unwrap(api.POST('/api/v1/job_postings/{job_posting_id}/requirements', {
        params: { path: { job_posting_id: postingId } },
        body: { requirement },
      })),
    onSuccess: refresh,
    onError,
  })
  const update = useMutation({
    mutationFn: ({ id, text }: { id: number; text: string }) =>
      unwrap(api.PATCH('/api/v1/requirements/{id}', { params: { path: { id } }, body: { requirement: { text } } })),
    onSuccess: refresh,
    onError,
  })
  const remove = useMutation({
    mutationFn: (id: number) => unwrap(api.DELETE('/api/v1/requirements/{id}', { params: { path: { id } } })),
    onSuccess: refresh,
    onError,
  })

  return (
    <Card
      title="Requirements"
      description="One line per requirement. Evidex will match each one against your CV and projects."
    >
      {error && (
        <div className="mb-4">
          <Alert tone="error">{error}</Alert>
        </div>
      )}
      <div className="space-y-6">
        {groups.map((group) => (
          <section key={group.kind} aria-label={group.title}>
            <h3 className="text-sm font-semibold">{group.title}</h3>
            <ul className="mt-2 space-y-1">
              {requirements
                .filter((requirement) => requirement.kind === group.kind)
                .map((requirement) => (
                  <RequirementRow
                    key={requirement.id}
                    requirement={requirement}
                    onSave={(text) => update.mutateAsync({ id: requirement.id, text })}
                    onRemove={() => remove.mutate(requirement.id)}
                  />
                ))}
            </ul>
            <AddRequirement
              label={`Add to ${group.title.toLowerCase()}`}
              placeholder={group.placeholder}
              onAdd={(text) => {
                setError(null)
                return add.mutateAsync({ kind: group.kind, text })
              }}
            />
          </section>
        ))}
      </div>
    </Card>
  )
}

function RequirementRow({
  requirement,
  onSave,
  onRemove,
}: {
  requirement: Requirement
  onSave: (text: string) => Promise<unknown>
  onRemove: () => void
}) {
  const [editing, setEditing] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const text = String(new FormData(event.currentTarget).get('text') ?? '').trim()
    if (!text) return
    await onSave(text).then(() => setEditing(false), () => undefined)
  }

  if (editing) {
    return (
      <li>
        <form onSubmit={handleSubmit} className="flex gap-2">
          <input name="text" aria-label="Requirement" defaultValue={requirement.text} className={inputClass} autoFocus />
          <Button type="submit">Save</Button>
          <Button type="button" variant="secondary" onClick={() => setEditing(false)}>
            Cancel
          </Button>
        </form>
      </li>
    )
  }

  return (
    <li className="group flex items-start justify-between gap-3 rounded px-2 py-1 text-sm hover:bg-slate-50 dark:hover:bg-slate-800/50">
      <span className="before:mr-2 before:text-slate-400 before:content-['•']">{requirement.text}</span>
      <span className="flex shrink-0 gap-3">
        <button type="button" className={linkButton} onClick={() => setEditing(true)} aria-label={`Edit "${requirement.text}"`}>
          Edit
        </button>
        <button type="button" className={linkButton} onClick={onRemove} aria-label={`Remove "${requirement.text}"`}>
          Remove
        </button>
      </span>
    </li>
  )
}

function AddRequirement({
  label,
  placeholder,
  onAdd,
}: {
  label: string
  placeholder: string
  onAdd: (text: string) => Promise<unknown>
}) {
  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = event.currentTarget
    const text = String(new FormData(form).get('text') ?? '').trim()
    if (!text) return
    await onAdd(text).then(() => form.reset(), () => undefined)
  }

  return (
    <form onSubmit={handleSubmit} className="mt-2 flex gap-2">
      <input name="text" aria-label={label} placeholder={placeholder} maxLength={1000} className={inputClass} />
      <Button type="submit" variant="secondary">
        Add
      </Button>
    </form>
  )
}
