import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { ApiError, api, unwrap, type JobPosting, type Requirement } from '../api/client'
import { Alert, Button, Card, Switch } from '../components/ui'
import { postingQueryKey } from './queries'

const groups: { kind: Requirement['kind']; title: string; placeholder: string }[] = [
  { kind: 'required', title: 'Required qualifications', placeholder: 'e.g. 3+ years with Ruby on Rails' },
  { kind: 'preferred', title: 'Nice to have', placeholder: 'e.g. Experience with pgvector' },
  { kind: 'responsibility', title: 'Responsibilities', placeholder: 'e.g. Design and build REST APIs' },
]

const inputClass =
  'block w-full rounded-md border-0 bg-white px-3 py-1.5 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700'
const linkButton = 'text-xs font-medium text-slate-500 hover:text-slate-900 hover:underline dark:hover:text-slate-100'

const SHOW_ORIGINAL_KEY = 'evidex.requirements.showOriginal'

/** "Finnish" for "fi"; falls back to the code if the browser doesn't know it. */
function languageName(code: string) {
  try {
    return new Intl.DisplayNames(['en'], { type: 'language' }).of(code) ?? code
  } catch {
    return code
  }
}

// The switch position is a per-browser convenience; storage may be unavailable.
function readShowOriginal() {
  try {
    return localStorage.getItem(SHOW_ORIGINAL_KEY) === 'true'
  } catch {
    return false
  }
}

function writeShowOriginal(value: boolean) {
  try {
    localStorage.setItem(SHOW_ORIGINAL_KEY, String(value))
  } catch {
    // Only the remembered position is lost
  }
}

export function RequirementsCard({ posting }: { posting: JobPosting }) {
  const postingId = posting.id
  const requirements = posting.requirements
  const queryClient = useQueryClient()
  const refresh = () => queryClient.invalidateQueries({ queryKey: postingQueryKey(postingId) })
  const [error, setError] = useState<string | null>(null)
  const [translated, setTranslated] = useState(false)
  const [showOriginalSetting, setShowOriginalSetting] = useState(readShowOriginal)

  const hasOriginals = requirements.some((requirement) => requirement.source_text)
  const showOriginal = hasOriginals && showOriginalSetting
  const originalLanguage = posting.language && posting.language !== 'en' ? languageName(posting.language) : null
  // Read before the ad reader translated into English: the lines may still be in the ad's language
  const canTranslate =
    !posting.language && posting.extraction.extracted_at !== null && requirements.some((requirement) => !requirement.source_text)
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
  const translate = useMutation({
    mutationFn: () =>
      unwrap(api.POST('/api/v1/job_postings/{job_posting_id}/translation', { params: { path: { job_posting_id: postingId } } })),
    onSuccess: ({ job_posting }) => {
      queryClient.setQueryData(postingQueryKey(postingId), job_posting)
      setTranslated(job_posting.requirements.some((requirement) => requirement.source_text))
    },
    onError,
  })

  return (
    <Card
      title="Requirements"
      description="One line per requirement, in English. Evidex will match each one against your CV and projects."
      action={
        hasOriginals && (
          <Switch
            label={originalLanguage ? `Original wording (${originalLanguage})` : 'Original wording'}
            checked={showOriginal}
            onChange={(value) => {
              setShowOriginalSetting(value)
              writeShowOriginal(value)
            }}
          />
        )
      }
    >
      {error && (
        <div className="mb-4">
          <Alert tone="error">{error}</Alert>
        </div>
      )}
      {canTranslate && (
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-md bg-slate-50 p-3 text-sm ring-1 ring-inset ring-slate-200 dark:bg-slate-800/50 dark:ring-slate-700">
          <p className="text-slate-700 dark:text-slate-300">
            This ad was read before Evidex translated requirements. If they aren't in English, translate them; the ad's own
            wording is kept.
          </p>
          <Button
            type="button"
            variant="secondary"
            disabled={translate.isPending}
            onClick={() => {
              setError(null)
              translate.mutate()
            }}
          >
            {translate.isPending ? 'Translating…' : 'Translate to English'}
          </Button>
        </div>
      )}
      {translated && (
        <div className="mb-4">
          <Alert tone="success">Translated to English. Run the match report again to get it in English too.</Alert>
        </div>
      )}
      {showOriginal && (
        <p className="mb-4 text-xs text-slate-500 dark:text-slate-400">
          Showing the ad's own wording. Matching uses the English; switch it off to edit.
        </p>
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
                    showOriginal={showOriginal}
                    originalLanguage={posting.language}
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
  showOriginal,
  originalLanguage,
  onSave,
  onRemove,
}: {
  requirement: Requirement
  showOriginal: boolean
  originalLanguage: string | null
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

  // Lines the user added themselves have no original and show in English either way
  const original = showOriginal ? requirement.source_text : null

  return (
    <li className="group flex items-start justify-between gap-3 rounded px-2 py-1 text-sm hover:bg-slate-50 dark:hover:bg-slate-800/50">
      <span className="before:mr-2 before:text-slate-400 before:content-['•']" lang={original ? (originalLanguage ?? undefined) : 'en'}>
        {original ?? requirement.text}
      </span>
      <span className="flex shrink-0 gap-3">
        {!showOriginal && (
          <button type="button" className={linkButton} onClick={() => setEditing(true)} aria-label={`Edit "${requirement.text}"`}>
            Edit
          </button>
        )}
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
