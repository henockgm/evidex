import { useQuery } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api, unwrap } from '../api/client'
import { Alert, Button } from '../components/ui'
import { libraryQueryKey } from './labels'

function escapeRegExp(text: string) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

/** Wraps the query's words in <mark>, without touching HTML (React escapes the text). */
function Highlighted({ text, query }: { text: string; query: string }) {
  const words = query.split(/\s+/).filter((word) => word.length > 1).map(escapeRegExp)
  if (!words.length) return <>{text}</>
  const pattern = new RegExp(`(${words.join('|')})`, 'gi')
  return (
    <>
      {text.split(pattern).map((part, index) =>
        index % 2 === 1 ? (
          <mark key={index} className="rounded bg-amber-200 px-0.5 text-inherit dark:bg-amber-700/60">
            {part}
          </mark>
        ) : (
          part
        ),
      )}
    </>
  )
}

/** One line of text, starting a little before the first word of the query if it's far in. */
function snippet(content: string, query: string) {
  const compact = content.replace(/\s*\n+\s*/g, ' · ')
  const words = query.toLowerCase().split(/\s+/).filter((word) => word.length > 1)
  const lower = compact.toLowerCase()
  const first = Math.min(...words.map((word) => lower.indexOf(word)).filter((index) => index >= 0))
  if (!Number.isFinite(first) || first < 120) return compact
  const start = compact.lastIndexOf(' ', first - 60)
  return `…${compact.slice(start + 1)}`
}

export function LibrarySearch() {
  const [query, setQuery] = useState('')
  const { data: results, isFetching, error } = useQuery({
    queryKey: [...libraryQueryKey, 'search', query],
    queryFn: async () => (await unwrap(api.GET('/api/v1/library/search', { params: { query: { q: query } } }))).results,
    enabled: query.length > 0,
  })

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setQuery(String(new FormData(event.currentTarget).get('q') ?? '').trim())
  }

  return (
    <div className="space-y-4">
      <form onSubmit={handleSubmit} role="search" className="flex gap-2">
        <input
          name="q"
          type="search"
          aria-label="Search your library"
          placeholder="e.g. building REST APIs, PostgreSQL, team lead"
          maxLength={500}
          className="block w-full rounded-md border-0 bg-white px-3 py-2 text-sm ring-1 ring-inset ring-slate-300 focus:ring-2 focus:ring-indigo-600 dark:bg-slate-900 dark:ring-slate-700"
        />
        <Button type="submit" disabled={isFetching}>
          {isFetching ? 'Searching…' : 'Search'}
        </Button>
      </form>

      {error && <Alert tone="error">{error.message}</Alert>}
      {query && results?.length === 0 && <p className="text-sm text-slate-500">Nothing in your library matches “{query}”.</p>}
      {results && results.length > 0 && (
        <ol aria-label="Search results" className="space-y-3">
          {results.map((result) => (
            <li key={result.chunk_id} className="rounded-md p-3 text-sm ring-1 ring-inset ring-slate-200 dark:ring-slate-800">
              <p className="flex flex-wrap items-center gap-x-2 text-xs text-slate-500">
                <span className="font-semibold text-slate-700 dark:text-slate-200">{result.document_title}</span>
                {result.page && <span>· page {result.page}</span>}
                {result.section && <span>· {result.section}</span>}
                <span>· {result.matched_by.length === 2 ? 'words and meaning' : result.matched_by[0] === 'keyword' ? 'words' : 'meaning'}</span>
              </p>
              <p className="mt-1 line-clamp-3">
                <Highlighted text={snippet(result.content, query)} query={query} />
              </p>
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}
