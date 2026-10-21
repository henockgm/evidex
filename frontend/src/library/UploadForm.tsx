import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useRef, useState, type FormEvent } from 'react'
import { ApiError, api, unwrap, type Document } from '../api/client'
import { Alert, Button, Field, Select } from '../components/ui'
import { ACCEPT, MAX_BYTES, kindLabels, libraryQueryKey } from './labels'

export function UploadForm() {
  const queryClient = useQueryClient()
  const formRef = useRef<HTMLFormElement>(null)
  const [localError, setLocalError] = useState<string | null>(null)

  const upload = useMutation({
    mutationFn: (fields: { file: File; title: string; kind: Document['kind'] }) =>
      unwrap(
        api.POST('/api/v1/documents', {
          // The schema types the binary part as a string; it is sent as multipart form data.
          body: { file: fields.file as unknown as string, title: fields.title || undefined, kind: fields.kind },
          bodySerializer: (body) => {
            const form = new FormData()
            const file = body.file as unknown as File
            form.append('file', file, file.name)
            if (body.title) form.append('title', body.title)
            if (body.kind) form.append('kind', body.kind)
            return form
          },
        }),
      ),
    onSuccess: () => {
      formRef.current?.reset()
      void queryClient.invalidateQueries({ queryKey: libraryQueryKey })
    },
  })
  const apiError = upload.error instanceof ApiError ? upload.error : null

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setLocalError(null)
    const form = new FormData(event.currentTarget)
    const file = (event.currentTarget.elements.namedItem('file') as HTMLInputElement | null)?.files?.[0]
    if (!file || file.size === 0) return setLocalError('Choose a file to upload.')
    if (file.size > MAX_BYTES) return setLocalError('The file is larger than 10 MB.')
    upload.mutate({ file, title: String(form.get('title') ?? '').trim(), kind: String(form.get('kind')) as Document['kind'] })
  }

  return (
    <form ref={formRef} onSubmit={handleSubmit} className="space-y-4">
      {localError && <Alert tone="error">{localError}</Alert>}
      {upload.isError && (
        <Alert tone="error">{apiError?.fieldErrors('file')[0] ?? upload.error.message}</Alert>
      )}
      <div className="grid gap-4 sm:grid-cols-3">
        <Field label="File" name="file" type="file" accept={ACCEPT} hint="PDF, Word (.docx), Markdown or text, up to 10 MB" />
        <Field label="Title" name="title" maxLength={200} placeholder="Defaults to the file name" />
        <Select
          label="Type"
          name="kind"
          defaultValue="cv"
          options={Object.entries(kindLabels).map(([value, label]) => ({ value, label }))}
        />
      </div>
      <Button type="submit" disabled={upload.isPending}>
        {upload.isPending ? 'Uploading…' : 'Upload'}
      </Button>
    </form>
  )
}
