import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { ApiError, api, unwrap, type ApplicationContact } from '../api/client'
import { Alert, Button, Card, Field, TextArea } from '../components/ui'
import { postingQueryKey } from '../postings/queries'

type ContactInput = Omit<ApplicationContact, 'id'>

const linkClass = 'text-indigo-600 hover:underline dark:text-indigo-400'

export function ContactsCard({
  postingId,
  applicationId,
  contacts,
}: {
  postingId: number
  applicationId: number
  contacts: ApplicationContact[]
}) {
  const queryClient = useQueryClient()
  const refresh = () => queryClient.invalidateQueries({ queryKey: postingQueryKey(postingId) })
  const [adding, setAdding] = useState(false)
  const [editingId, setEditingId] = useState<number | null>(null)

  const add = useMutation({
    mutationFn: (contact: ContactInput) =>
      unwrap(api.POST('/api/v1/job_applications/{job_application_id}/contacts', {
        params: { path: { job_application_id: applicationId } },
        body: { contact },
      })),
    onSuccess: async () => {
      await refresh()
      setAdding(false)
    },
  })
  const update = useMutation({
    mutationFn: ({ id, contact }: { id: number; contact: ContactInput }) =>
      unwrap(api.PATCH('/api/v1/contacts/{id}', { params: { path: { id } }, body: { contact } })),
    onSuccess: async () => {
      await refresh()
      setEditingId(null)
    },
  })
  const remove = useMutation({
    mutationFn: (id: number) => unwrap(api.DELETE('/api/v1/contacts/{id}', { params: { path: { id } } })),
    onSuccess: refresh,
  })

  return (
    <Card title="Contacts" description="Recruiters, hiring managers and anyone who referred you.">
      {remove.isError && (
        <div className="mb-4">
          <Alert tone="error">{remove.error.message}</Alert>
        </div>
      )}
      {contacts.length === 0 && !adding && <p className="text-sm text-slate-500">No contacts yet.</p>}

      <ul className="divide-y divide-slate-200 dark:divide-slate-800">
        {contacts.map((contact) =>
          editingId === contact.id ? (
            <li key={contact.id} className="py-4">
              <ContactForm
                initial={contact}
                submitLabel="Save contact"
                pending={update.isPending}
                error={update.error}
                onSubmit={(input) => update.mutate({ id: contact.id, contact: input })}
                onCancel={() => setEditingId(null)}
              />
            </li>
          ) : (
            <li key={contact.id} className="flex flex-wrap items-start justify-between gap-3 py-3 text-sm">
              <div className="space-y-0.5">
                <p>
                  <span className="font-medium">{contact.name}</span>
                  {contact.role && <span className="text-slate-500"> · {contact.role}</span>}
                </p>
                {(contact.email || contact.phone) && (
                  <p className="flex flex-wrap gap-x-3">
                    {contact.email && (
                      <a className={linkClass} href={`mailto:${contact.email}`}>
                        {contact.email}
                      </a>
                    )}
                    {contact.phone && (
                      <a className={linkClass} href={`tel:${contact.phone.replace(/[^0-9+]/g, '')}`}>
                        {contact.phone}
                      </a>
                    )}
                  </p>
                )}
                {contact.notes && <p className="whitespace-pre-wrap text-slate-600 dark:text-slate-400">{contact.notes}</p>}
              </div>
              <div className="flex gap-2">
                <Button variant="secondary" onClick={() => setEditingId(contact.id)} aria-label={`Edit ${contact.name}`}>
                  Edit
                </Button>
                <Button
                  variant="secondary"
                  onClick={() => remove.mutate(contact.id)}
                  disabled={remove.isPending}
                  aria-label={`Remove ${contact.name}`}
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
          <ContactForm
            submitLabel="Add contact"
            pending={add.isPending}
            error={add.error}
            onSubmit={(input) => add.mutate(input)}
            onCancel={() => setAdding(false)}
          />
        </div>
      ) : (
        <Button variant="secondary" className="mt-4" onClick={() => setAdding(true)}>
          Add contact
        </Button>
      )}
    </Card>
  )
}

function ContactForm({
  initial,
  submitLabel,
  pending,
  error,
  onSubmit,
  onCancel,
}: {
  initial?: ApplicationContact
  submitLabel: string
  pending: boolean
  error: Error | null
  onSubmit: (input: ContactInput) => void
  onCancel: () => void
}) {
  const apiError = error instanceof ApiError ? error : null

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const value = (name: string) => String(form.get(name) ?? '').trim() || null
    onSubmit({
      name: value('name') ?? '',
      role: value('role'),
      email: value('email'),
      phone: value('phone'),
      notes: value('notes'),
    })
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && !apiError?.problem?.errors && <Alert tone="error">{error.message}</Alert>}
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Name" name="name" required maxLength={100} defaultValue={initial?.name ?? ''} errors={apiError?.fieldErrors('name')} />
        <Field
          label="Role"
          name="role"
          maxLength={100}
          placeholder="e.g. Recruiter"
          defaultValue={initial?.role ?? ''}
          errors={apiError?.fieldErrors('role')}
        />
        <Field label="Email" name="email" type="email" defaultValue={initial?.email ?? ''} errors={apiError?.fieldErrors('email')} />
        <Field label="Phone" name="phone" type="tel" maxLength={40} defaultValue={initial?.phone ?? ''} errors={apiError?.fieldErrors('phone')} />
      </div>
      <TextArea label="Notes about this contact" name="notes" rows={2} maxLength={2000} defaultValue={initial?.notes ?? ''} />
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
