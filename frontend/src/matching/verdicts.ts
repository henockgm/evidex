import type { RequirementMatch } from '../api/client'

export type Verdict = RequirementMatch['verdict']

export const verdictLabels: Record<Verdict, string> = {
  evidenced: 'Evidenced',
  transferable: 'Transferable',
  gap: 'Gap',
}

export const verdictDescriptions: Record<Verdict, string> = {
  evidenced: 'Your documents directly show this.',
  transferable: 'Related experience that would carry over.',
  gap: 'No supporting evidence found.',
}

export const verdictTones: Record<Verdict, string> = {
  evidenced: 'bg-emerald-50 text-emerald-800 ring-emerald-200 dark:bg-emerald-950 dark:text-emerald-200 dark:ring-emerald-900',
  transferable: 'bg-amber-50 text-amber-800 ring-amber-200 dark:bg-amber-950 dark:text-amber-200 dark:ring-amber-900',
  gap: 'bg-rose-50 text-rose-800 ring-rose-200 dark:bg-rose-950 dark:text-rose-200 dark:ring-rose-900',
}

export const matchReportQueryKey = (postingId: number) => ['job-postings', postingId, 'match-report'] as const
