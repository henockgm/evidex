import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useEffect, useRef, useState } from 'react'
import { Link, useSearchParams } from 'react-router'
import { api, unwrap, type ApplicationStatus } from '../api/client'
import { StatusBadge } from '../applications/StatusBadge'
import { statusLabels } from '../applications/labels'
import { Alert, Button, Spinner } from '../components/ui'
import { formatDate, workModelLabels } from '../postings/labels'
import { postingListsQueryKey } from '../postings/queries'

const statuses = Object.keys(statusLabels) as ApplicationStatus[]

const deadlineOptions = [
  { value: '', label: 'Any deadline' },
  { value: 'upcoming', label: 'Due within 7 days' },
  { value: 'overdue', label: 'Deadline passed' },
  { value: 'none', label: 'No deadline' },
] as const

const sortOptions = [
  { value: 'newest', label: 'Newest first' },
  { value: 'oldest', label: 'Oldest first' },
  { value: 'deadline', label: 'Deadline' },
  { value: 'next_action', label: 'Next action date' },
  { value: 'company', label: 'Company' },
  { value: 'updated', label: 'Recently updated' },
] as const

type Deadline = Exclude<(typeof deadlineOptions)[number]['value'], ''>
type Sort = (typeof sortOptions)[number]['value']

const selectClass =
  'rounded-md border-0 bg-white py-1.5 pl-3 pr-8 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700'

export function PostingsPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const selectedStatuses = (searchParams.get('status') ?? '').split(',').filter(Boolean) as ApplicationStatus[]
  const q = searchParams.get('q') ?? ''
  const deadline = (searchParams.get('deadline') ?? '') as Deadline | ''
  const sort = (searchParams.get('sort') ?? 'newest') as Sort
  const page = Math.max(Number(searchParams.get('page')) || 1, 1)
  const filtering = selectedStatuses.length > 0 || q !== '' || deadline !== ''

  /** Updates the URL; any filter change goes back to page 1. */
  function setParam(name: string, value: string) {
    setSearchParams(
      (current) => {
        const next = new URLSearchParams(current)
        if (value) next.set(name, value)
        else next.delete(name)
        if (name !== 'page') next.delete('page')
        return next
      },
      { replace: name === 'q' },
    )
  }

  function toggleStatus(status: ApplicationStatus) {
    const next = selectedStatuses.includes(status)
      ? selectedStatuses.filter((selected) => selected !== status)
      : [...selectedStatuses, status]
    setParam('status', next.join(','))
  }

  const query = {
    status: selectedStatuses.join(',') || undefined,
    q: q || undefined,
    deadline: deadline || undefined,
    sort,
    page,
  }
  const { data, isPending, isFetching, error } = useQuery({
    queryKey: [...postingListsQueryKey, query],
    queryFn: () => unwrap(api.GET('/api/v1/job_postings', { params: { query } })),
    placeholderData: keepPreviousData,
  })
  const postings = data?.job_postings
  const meta = data?.meta

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-2xl font-bold tracking-tight">Job postings</h1>
        <Link
          to="/postings/new"
          className="rounded-md bg-indigo-600 px-3.5 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
        >
          Add posting
        </Link>
      </div>

      <section aria-label="Filters" className="space-y-3">
        <div className="flex flex-wrap gap-2">
          <SearchInput value={q} onChange={(value) => setParam('q', value)} />
          <select
            aria-label="Deadline"
            className={selectClass}
            value={deadline}
            onChange={(event) => setParam('deadline', event.target.value)}
          >
            {deadlineOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
          <select
            aria-label="Sort by"
            className={selectClass}
            value={sort}
            onChange={(event) => setParam('sort', event.target.value === 'newest' ? '' : event.target.value)}
          >
            {sortOptions.map((option) => (
              <option key={option.value} value={option.value}>
                Sort: {option.label}
              </option>
            ))}
          </select>
        </div>
        <div className="flex flex-wrap items-center gap-2" role="group" aria-label="Status">
          {statuses.map((status) => {
            const selected = selectedStatuses.includes(status)
            return (
              <button
                key={status}
                type="button"
                aria-pressed={selected}
                onClick={() => toggleStatus(status)}
                className={`rounded-full px-3 py-1 text-xs font-semibold ring-1 ring-inset transition ${
                  selected
                    ? 'bg-indigo-600 text-white ring-indigo-600'
                    : 'bg-white text-slate-700 ring-slate-300 hover:bg-slate-50 dark:bg-slate-900 dark:text-slate-200 dark:ring-slate-700 dark:hover:bg-slate-800'
                }`}
              >
                {statusLabels[status]}
              </button>
            )
          })}
          {filtering && (
            <button
              type="button"
              onClick={() => setSearchParams(sort === 'newest' ? {} : { sort })}
              className="text-xs font-medium text-slate-500 hover:text-slate-900 hover:underline dark:hover:text-slate-100"
            >
              Clear filters
            </button>
          )}
        </div>
      </section>

      {isPending && <Spinner />}
      {error && <Alert tone="error">{error.message}</Alert>}
      {postings?.length === 0 && (
        <div className="rounded-lg border border-dashed border-slate-300 p-10 text-center text-sm text-slate-500 dark:border-slate-700">
          {filtering ? 'No postings match these filters.' : "No postings yet. Add one by pasting the job ad's text or a link."}
        </div>
      )}

      {postings && postings.length > 0 && (
        <ul
          aria-busy={isFetching}
          className={`divide-y divide-slate-200 overflow-hidden rounded-lg bg-white shadow-sm ring-1 ring-slate-200 transition-opacity dark:divide-slate-800 dark:bg-slate-900 dark:ring-slate-800 ${isFetching ? 'opacity-60' : ''}`}
        >
          {postings.map((posting) => (
            <li key={posting.id}>
              <Link to={`/postings/${posting.id}`} className="block px-5 py-4 hover:bg-slate-50 dark:hover:bg-slate-800/50">
                <div className="flex items-center justify-between gap-3">
                  <p className="font-medium">{posting.title}</p>
                  <StatusBadge status={posting.status} />
                </div>
                <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
                  {[posting.company, posting.location, posting.work_model && workModelLabels[posting.work_model]]
                    .filter(Boolean)
                    .join(' · ')}
                  {posting.deadline && <> · Deadline {formatDate(posting.deadline)}</>}
                </p>
              </Link>
            </li>
          ))}
        </ul>
      )}

      {meta && meta.total > 0 && (
        <nav aria-label="Pages" className="flex items-center justify-between gap-4 text-sm">
          <p className="text-slate-500">
            Showing {(meta.page - 1) * meta.per_page + 1}–{Math.min(meta.page * meta.per_page, meta.total)} of {meta.total}
          </p>
          {meta.total_pages > 1 && (
            <div className="flex gap-2">
              <Button variant="secondary" disabled={meta.page <= 1} onClick={() => setParam('page', String(meta.page - 1))}>
                Previous
              </Button>
              <Button
                variant="secondary"
                disabled={meta.page >= meta.total_pages}
                onClick={() => setParam('page', String(meta.page + 1))}
              >
                Next
              </Button>
            </div>
          )}
        </nav>
      )}
    </div>
  )
}

/** Search box that updates the URL 300 ms after the user stops typing. */
function SearchInput({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  const [text, setText] = useState(value)
  const [lastValue, setLastValue] = useState(value)
  const onChangeRef = useRef(onChange)

  useEffect(() => {
    onChangeRef.current = onChange
  })

  // The URL changed from outside (e.g. "Clear filters"): show its value.
  if (value !== lastValue) {
    setLastValue(value)
    setText(value)
  }

  useEffect(() => {
    if (text.trim() === value) return
    const timer = setTimeout(() => onChangeRef.current(text.trim()), 300)
    return () => clearTimeout(timer)
  }, [text, value])

  return (
    <input
      type="search"
      aria-label="Search postings"
      placeholder="Search title, company or location"
      value={text}
      onChange={(event) => setText(event.target.value)}
      className="min-w-0 flex-1 rounded-md border-0 bg-white px-3 py-1.5 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700 sm:min-w-[16rem]"
    />
  )
}
