import { useQuery } from '@tanstack/react-query'
import { api, unwrap } from '../api/client'

export function useProviders() {
  return useQuery({
    queryKey: ['auth-providers'],
    queryFn: async () => (await unwrap(api.GET('/api/v1/auth/providers'))).providers,
    staleTime: Infinity,
  })
}
