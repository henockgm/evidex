export const postingsQueryKey = ['job-postings'] as const

export const postingQueryKey = (id: number) => [...postingsQueryKey, id] as const
