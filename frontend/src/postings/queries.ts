export const postingsQueryKey = ['job-postings'] as const

/** All list queries (any filters); invalidate this after changing a posting or its status. */
export const postingListsQueryKey = [...postingsQueryKey, 'list'] as const

export const postingQueryKey = (id: number) => [...postingsQueryKey, id] as const
