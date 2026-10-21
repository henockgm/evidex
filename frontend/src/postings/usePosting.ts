import { useQuery } from '@tanstack/react-query'
import { api, unwrap } from '../api/client'
import { postingQueryKey } from './queries'

export function usePosting(id: number) {
  return useQuery({
    queryKey: postingQueryKey(id),
    queryFn: async () => (await unwrap(api.GET('/api/v1/job_postings/{id}', { params: { path: { id } } }))).job_posting,
    // Poll while AI extraction runs in the background.
    refetchInterval: (query) => (query.state.data?.extraction.status === 'pending' ? 2000 : false),
  })
}
