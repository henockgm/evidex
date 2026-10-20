import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback } from 'react'
import { ApiError, api, resetCsrfToken, unwrap, type User } from '../api/client'

export const meQueryKey = ['me'] as const

async function fetchMe(): Promise<User | null> {
  const { data, error, response } = await api.GET('/api/v1/me')
  if (response.status === 401) return null
  if (!response.ok || !data) throw new ApiError(response.status, error)
  return data.user
}

export function useMe() {
  return useQuery({ queryKey: meQueryKey, queryFn: fetchMe, staleTime: 60_000 })
}

/** Call after signing in or changing the current user (pass it if you have it). */
export function useAuthChanged() {
  const queryClient = useQueryClient()
  return useCallback(
    (user?: User) => {
      resetCsrfToken()
      if (user) queryClient.setQueryData(meQueryKey, user)
      else void queryClient.invalidateQueries({ queryKey: meQueryKey })
    },
    [queryClient],
  )
}

/**
 * After signing out or deleting the account, reload the app at `path` so no
 * signed-in data stays in memory and the route guards start fresh.
 */
export function leaveApp(path: string) {
  window.location.assign(path)
}

export async function signOut() {
  await unwrap(api.DELETE('/api/v1/session'))
}
