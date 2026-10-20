export class ApiError extends Error {
  readonly status: number

  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

export async function apiGet<T>(path: string): Promise<T> {
  const response = await fetch(`/api/v1${path}`, {
    headers: { Accept: 'application/json' },
    credentials: 'same-origin',
  })

  if (!response.ok) {
    throw new ApiError(response.status, `Request to ${path} failed with ${response.status}`)
  }

  return (await response.json()) as T
}
