import type { JobPostingSummary } from '../api/client'

export const workModelLabels: Record<NonNullable<JobPostingSummary['work_model']>, string> = {
  onsite: 'On-site',
  hybrid: 'Hybrid',
  remote: 'Remote',
}

const dateFormat = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeZone: 'UTC' })

/** Formats an ISO date (YYYY-MM-DD) without shifting it across time zones. */
export function formatDate(isoDate: string) {
  return dateFormat.format(new Date(`${isoDate}T00:00:00Z`))
}
