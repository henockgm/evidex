import type { FormEvent } from 'react'
import { ApiError, type JobPostingInput } from '../api/client'
import { Alert, Button, Field, Select, TextArea } from '../components/ui'
import { workModelLabels } from './labels'

const workModelOptions = [
  { value: '', label: 'Not specified' },
  ...Object.entries(workModelLabels).map(([value, label]) => ({ value, label })),
]

function text(form: FormData, name: string) {
  return String(form.get(name) ?? '').trim()
}

interface Props {
  initial?: JobPostingInput
  submitLabel: string
  pending: boolean
  error: Error | null
  onSubmit: (input: JobPostingInput) => void
  onCancel: () => void
}

export function PostingForm({ initial, submitLabel, pending, error, onSubmit, onCancel }: Props) {
  const apiError = error instanceof ApiError ? error : null
  const errorsFor = (field: string) => apiError?.fieldErrors(field)

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    onSubmit({
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
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && !apiError?.problem?.errors && <Alert tone="error">{error.message}</Alert>}
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Job title" name="title" required maxLength={200} defaultValue={initial?.title ?? ''} errors={errorsFor('title')} />
        <Field label="Company" name="company" required maxLength={200} defaultValue={initial?.company ?? ''} errors={errorsFor('company')} />
        <Field
          label="Location"
          name="location"
          maxLength={200}
          defaultValue={initial?.location ?? ''}
          errors={errorsFor('location')}
        />
        <Select
          label="Work model"
          name="work_model"
          options={workModelOptions}
          defaultValue={initial?.work_model ?? ''}
          errors={errorsFor('work_model')}
        />
        <Field
          label="Application deadline"
          name="deadline"
          type="date"
          defaultValue={initial?.deadline ?? ''}
          errors={errorsFor('deadline')}
        />
        <Field
          label="Link to the ad"
          name="source_url"
          type="url"
          placeholder="https://"
          defaultValue={initial?.source_url ?? ''}
          errors={errorsFor('source_url')}
        />
      </div>
      <TextArea
        label="Job ad text"
        name="description"
        required
        rows={14}
        defaultValue={initial?.description ?? ''}
        hint="Paste the whole ad: responsibilities, requirements, how to apply."
        errors={errorsFor('description')}
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
