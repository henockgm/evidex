import type {
  ButtonHTMLAttributes,
  InputHTMLAttributes,
  ReactNode,
  SelectHTMLAttributes,
  TextareaHTMLAttributes,
} from 'react'
import { useId } from 'react'

const variants = {
  primary: 'bg-indigo-600 text-white hover:bg-indigo-500 focus-visible:outline-indigo-600',
  secondary:
    'bg-white text-slate-900 ring-1 ring-inset ring-slate-300 hover:bg-slate-50 dark:bg-slate-900 dark:text-slate-100 dark:ring-slate-700 dark:hover:bg-slate-800',
  danger: 'bg-red-600 text-white hover:bg-red-500 focus-visible:outline-red-600',
}

export function Button({
  variant = 'primary',
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: keyof typeof variants }) {
  return (
    <button
      className={`inline-flex items-center justify-center gap-2 rounded-md px-3.5 py-2 text-sm font-semibold shadow-sm focus-visible:outline-2 focus-visible:outline-offset-2 disabled:cursor-not-allowed disabled:opacity-60 ${variants[variant]} ${className}`}
      {...props}
    />
  )
}

const controlClass =
  'block w-full rounded-md border-0 bg-white px-3 py-2 text-sm ring-1 ring-inset ring-slate-300 placeholder:text-slate-400 focus:ring-2 focus:ring-indigo-600 aria-invalid:ring-red-500 dark:bg-slate-900 dark:ring-slate-700'

interface FieldProps {
  label: string
  errors?: string[]
  hint?: string
}

/** Label, hint and error list around one form control; renders the control via `children(props)`. */
function FieldShell({
  label,
  errors = [],
  hint,
  children,
}: FieldProps & { children: (props: { id: string; 'aria-invalid'?: true; 'aria-describedby'?: string }) => ReactNode }) {
  const id = useId()
  const describedBy = errors.length ? `${id}-errors` : hint ? `${id}-hint` : undefined

  return (
    <div className="space-y-1">
      <label htmlFor={id} className="block text-sm font-medium">
        {label}
      </label>
      {children({ id, 'aria-invalid': errors.length > 0 || undefined, 'aria-describedby': describedBy })}
      {hint && !errors.length && (
        <p id={`${id}-hint`} className="text-xs text-slate-500 dark:text-slate-400">
          {hint}
        </p>
      )}
      {errors.length > 0 && (
        <ul id={`${id}-errors`} className="text-xs text-red-600 dark:text-red-400">
          {errors.map((error) => (
            <li key={error}>{error}</li>
          ))}
        </ul>
      )}
    </div>
  )
}

export function Field({ label, errors, hint, ...props }: InputHTMLAttributes<HTMLInputElement> & FieldProps) {
  return (
    <FieldShell label={label} errors={errors} hint={hint}>
      {(control) => <input className={controlClass} {...control} {...props} />}
    </FieldShell>
  )
}

export function TextArea({ label, errors, hint, ...props }: TextareaHTMLAttributes<HTMLTextAreaElement> & FieldProps) {
  return (
    <FieldShell label={label} errors={errors} hint={hint}>
      {(control) => <textarea className={controlClass} {...control} {...props} />}
    </FieldShell>
  )
}

export function Select({
  label,
  errors,
  hint,
  options,
  ...props
}: SelectHTMLAttributes<HTMLSelectElement> & FieldProps & { options: { value: string; label: string }[] }) {
  return (
    <FieldShell label={label} errors={errors} hint={hint}>
      {(control) => (
        <select className={controlClass} {...control} {...props}>
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      )}
    </FieldShell>
  )
}

const tones = {
  error: 'bg-red-50 text-red-800 ring-red-200 dark:bg-red-950/50 dark:text-red-200 dark:ring-red-900',
  success:
    'bg-emerald-50 text-emerald-800 ring-emerald-200 dark:bg-emerald-950/50 dark:text-emerald-200 dark:ring-emerald-900',
  info: 'bg-sky-50 text-sky-800 ring-sky-200 dark:bg-sky-950/50 dark:text-sky-200 dark:ring-sky-900',
  warning: 'bg-amber-50 text-amber-900 ring-amber-200 dark:bg-amber-950/50 dark:text-amber-100 dark:ring-amber-900',
}

export function Alert({ tone = 'info', children }: { tone?: keyof typeof tones; children: ReactNode }) {
  return (
    <div role={tone === 'error' ? 'alert' : 'status'} className={`rounded-md p-3 text-sm ring-1 ring-inset ${tones[tone]}`}>
      {children}
    </div>
  )
}

export function Card({ title, description, children }: { title: string; description?: string; children: ReactNode }) {
  return (
    <section className="rounded-lg bg-white p-6 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
      <h2 className="text-base font-semibold">{title}</h2>
      {description && <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">{description}</p>}
      <div className="mt-4">{children}</div>
    </section>
  )
}

export function AuthCard({ title, children, footer }: { title: string; children: ReactNode; footer?: ReactNode }) {
  return (
    <div className="mx-auto w-full max-w-sm">
      <h1 className="mb-6 text-center text-2xl font-bold tracking-tight">{title}</h1>
      <div className="space-y-6 rounded-lg bg-white p-6 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        {children}
      </div>
      {footer && <div className="mt-6 text-center text-sm text-slate-600 dark:text-slate-400">{footer}</div>}
    </div>
  )
}

export function Spinner({ label = 'Loading…' }: { label?: string }) {
  return (
    <p role="status" className="py-12 text-center text-sm text-slate-500">
      {label}
    </p>
  )
}
