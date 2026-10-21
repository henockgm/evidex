import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api, unwrap, type Document } from '../api/client'
import { Alert, Button, Card, Spinner } from '../components/ui'
import { UploadForm } from '../library/UploadForm'
import { documentStatusLabels, formatBytes, kindLabels, libraryQueryKey } from '../library/labels'

const dateFormat = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' })
const smallInput =
  'rounded-md border-0 bg-white px-2 py-1 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700'

export function LibraryPage() {
  const { data: documents, isPending, error } = useQuery({
    queryKey: libraryQueryKey,
    queryFn: async () => (await unwrap(api.GET('/api/v1/documents'))).documents,
  })

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Career library</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Your CVs, project write-ups, certificates and references. Evidex reads them to find evidence for each job
          requirement.
        </p>
      </div>

      <Card title="Upload a document">
        <UploadForm />
      </Card>

      {isPending && <Spinner />}
      {error && <Alert tone="error">{error.message}</Alert>}
      {documents?.length === 0 && (
        <div className="rounded-lg border border-dashed border-slate-300 p-10 text-center text-sm text-slate-500 dark:border-slate-700">
          No documents yet. Start with your CV.
        </div>
      )}
      {documents && documents.length > 0 && (
        <ul className="divide-y divide-slate-200 overflow-hidden rounded-lg bg-white shadow-sm ring-1 ring-slate-200 dark:divide-slate-800 dark:bg-slate-900 dark:ring-slate-800">
          {documents.map((document) => (
            <DocumentRow key={document.id} document={document} />
          ))}
        </ul>
      )}
    </div>
  )
}

function DocumentRow({ document }: { document: Document }) {
  const queryClient = useQueryClient()
  const refresh = () => queryClient.invalidateQueries({ queryKey: libraryQueryKey })
  const [editing, setEditing] = useState(false)
  const [confirmingDelete, setConfirmingDelete] = useState(false)

  const update = useMutation({
    mutationFn: (changes: { title?: string; kind?: Document['kind']; primary?: boolean }) =>
      unwrap(api.PATCH('/api/v1/documents/{id}', { params: { path: { id: document.id } }, body: { document: changes } })),
    onSuccess: async () => {
      await refresh()
      setEditing(false)
    },
  })
  const remove = useMutation({
    mutationFn: () => unwrap(api.DELETE('/api/v1/documents/{id}', { params: { path: { id: document.id } } })),
    onSuccess: refresh,
  })

  function handleRename(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    update.mutate({ title: String(form.get('title') ?? '').trim(), kind: String(form.get('kind')) as Document['kind'] })
  }

  return (
    <li className="space-y-2 px-5 py-4 text-sm">
      {editing ? (
        <form onSubmit={handleRename} className="flex flex-wrap items-center gap-2">
          <input name="title" aria-label="Title" defaultValue={document.title} maxLength={200} required className={`${smallInput} min-w-0 flex-1`} />
          <select name="kind" aria-label="Type" defaultValue={document.kind} className={smallInput}>
            {Object.entries(kindLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
          <Button type="submit" disabled={update.isPending}>
            Save
          </Button>
          <Button type="button" variant="secondary" onClick={() => setEditing(false)}>
            Cancel
          </Button>
        </form>
      ) : (
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="min-w-0">
            <p className="flex flex-wrap items-center gap-2">
              <span className="font-medium">{document.title}</span>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700 dark:bg-slate-800 dark:text-slate-200">
                {kindLabels[document.kind]}
              </span>
              {document.primary && (
                <span className="rounded-full bg-indigo-50 px-2 py-0.5 text-xs font-semibold text-indigo-700 ring-1 ring-inset ring-indigo-200 dark:bg-indigo-950 dark:text-indigo-200 dark:ring-indigo-900">
                  Primary CV
                </span>
              )}
            </p>
            <p className="mt-0.5 text-slate-500">
              {document.filename} · {formatBytes(document.byte_size)} · added {dateFormat.format(new Date(document.created_at))} ·{' '}
              {documentStatusLabels[document.status]}
            </p>
            {document.status === 'failed' && document.error && <p className="text-rose-700 dark:text-rose-300">{document.error}</p>}
          </div>
          <div className="flex flex-wrap gap-2">
            <a
              href={`/api/v1/documents/${document.id}/file`}
              className="rounded-md bg-white px-3 py-2 text-sm font-semibold shadow-sm ring-1 ring-inset ring-slate-300 hover:bg-slate-50 dark:bg-slate-900 dark:ring-slate-700 dark:hover:bg-slate-800"
            >
              Download
            </a>
            {document.kind === 'cv' && !document.primary && (
              <Button variant="secondary" onClick={() => update.mutate({ primary: true })} disabled={update.isPending}>
                Make primary
              </Button>
            )}
            <Button variant="secondary" onClick={() => setEditing(true)} aria-label={`Edit ${document.title}`}>
              Edit
            </Button>
            {!confirmingDelete && (
              <Button variant="secondary" onClick={() => setConfirmingDelete(true)} aria-label={`Delete ${document.title}`}>
                Delete
              </Button>
            )}
          </div>
        </div>
      )}
      {update.isError && <Alert tone="error">{update.error.message}</Alert>}
      {confirmingDelete && (
        <Alert tone="error">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <span>Delete “{document.title}” and its file? This can't be undone.</span>
            <div className="flex gap-2">
              <Button variant="secondary" onClick={() => setConfirmingDelete(false)} disabled={remove.isPending}>
                Cancel
              </Button>
              <Button variant="danger" onClick={() => remove.mutate()} disabled={remove.isPending}>
                {remove.isPending ? 'Deleting…' : 'Delete document'}
              </Button>
            </div>
          </div>
        </Alert>
      )}
    </li>
  )
}
