import createClient, { type Middleware } from 'openapi-fetch'
import type { components, paths } from './schema'

export type User = components['schemas']['User']
export type Identity = components['schemas']['Identity']
export type Session = components['schemas']['Session']
export type Problem = components['schemas']['Problem']

export class ApiError extends Error {
  readonly status: number
  readonly problem?: Problem

  constructor(status: number, problem?: Problem) {
    super(problem?.detail ?? problem?.title ?? `Request failed with ${status}`)
    this.status = status
    this.problem = problem
  }

  fieldErrors(field: string): string[] {
    return this.problem?.errors?.[field] ?? []
  }
}

// Rails ties the CSRF token to its session, which is replaced on sign-in and
// sign-out, so call resetCsrfToken() after either.
let csrfToken: string | null = null

export function resetCsrfToken() {
  csrfToken = null
}

export async function getCsrfToken(): Promise<string> {
  if (!csrfToken) {
    const response = await globalThis.fetch('/api/v1/csrf_token', {
      credentials: 'same-origin',
      headers: { Accept: 'application/json' },
    })
    if (!response.ok) throw new ApiError(response.status)
    csrfToken = ((await response.json()) as { csrf_token: string }).csrf_token
  }
  return csrfToken
}

const csrf: Middleware = {
  async onRequest({ request }) {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      request.headers.set('X-CSRF-Token', await getCsrfToken())
    }
    return request
  },
}

export const api = createClient<paths>({
  // Absolute URLs: the Fetch API's Request rejects relative ones outside a browser (tests).
  baseUrl: globalThis.location?.origin ?? '',
  // Resolve fetch per call so tests can stub it.
  fetch: (request) => globalThis.fetch(request),
  credentials: 'same-origin',
  headers: { Accept: 'application/json' },
})
api.use(csrf)

interface FetchResult<T> {
  data?: T
  error?: unknown
  response: Response
}

/** Returns the response data, or throws an ApiError carrying the problem details. */
export async function unwrap<T>(request: Promise<FetchResult<T>>): Promise<T> {
  const { data, error, response } = await request
  if (!response.ok) throw new ApiError(response.status, error as Problem | undefined)
  return data as T
}
