import { useRef, type FormEvent } from 'react'
import { ApiError, type JobPostingInput, type JobPostingSummary } from '../api/client'
import { Alert, Button, Field, Select, TextArea } from '../components/ui'
import { DuplicateWarning } from './DuplicateWarning'
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
  /** Postings already saved for the same job ad; the form offers "Save anyway". */
  duplicates?: JobPostingSummary[]
  submitLabel: string
  pending: boolean
  error: Error | null
  onSubmit: (input: JobPostingInput, options: { confirmDuplicate: boolean }) => void
  onCancel: () => void
}

export function PostingForm({ initial, duplicates, submitLabel, pending, error, onSubmit, onCancel }: Props) {
  const apiError = error instanceof ApiError ? error : null
  const errorsFor = (field: string) => apiError?.fieldErrors(field)
  const formRef = useRef<HTMLFormElement>(null)

  function submit(formElement: HTMLFormElement, confirmDuplicate: boolean) {
    const form = new FormData(formElement)
    onSubmit({
      title: text(form, 'title'),
      company: text(form, 'company'),
      location: text(form, 'location') || null,
      work_model: (text(form, 'work_model') || null) as JobPostingInput['work_model'],
      employment_type: text(form, 'employment_type') || null,
      seniority: text(form, 'seniority') || null,
      salary: text(form, 'salary') || null,
      deadline: text(form, 'deadline') || null,
      source_url: text(form, 'source_url') || null,
      description: text(form, 'description'),
    }, { confirmDuplicate })
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    submit(event.currentTarget, false)
  }

  function saveAnyway() {
    const form = formRef.current
    if (form?.reportValidity()) submit(form, true)
  }

  return (
    <form ref={formRef} onSubmit={handleSubmit} className="space-y-4">
      {error && !apiError?.problem?.errors && <Alert tone="error">{error.message}</Alert>}
      {duplicates && duplicates.length > 0 && (
        <DuplicateWarning duplicates={duplicates}>
          <p className="mt-3 flex flex-wrap items-center gap-3">
            <span>Is this a different job, or do you want a second copy?</span>
            <Button type="button" variant="secondary" disabled={pending} onClick={saveAnyway}>
              Save anyway
            </Button>
          </p>
        </DuplicateWarning>
      )}
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
          label="Employment type"
          name="employment_type"
          maxLength={200}
          placeholder="e.g. Full-time"
          defaultValue={initial?.employment_type ?? ''}
          errors={errorsFor('employment_type')}
        />
        <Field
          label="Seniority"
          name="seniority"
          maxLength={200}
          placeholder="e.g. Senior"
          defaultValue={initial?.seniority ?? ''}
          errors={errorsFor('seniority')}
        />
        <Field
          label="Salary"
          name="salary"
          maxLength={200}
          placeholder="As stated in the ad"
          defaultValue={initial?.salary ?? ''}
          errors={errorsFor('salary')}
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
