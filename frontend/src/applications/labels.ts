import type { ApplicationStatus } from '../api/client'

export const statusLabels: Record<ApplicationStatus, string> = {
  saved: 'Saved',
  preparing: 'Preparing',
  applied: 'Applied',
  interviewing: 'Interviewing',
  offer: 'Offer',
  rejected: 'Rejected',
  withdrawn: 'Withdrawn',
}

/** Wording for the button that moves an application to a status. */
export const transitionLabels: Record<ApplicationStatus, string> = {
  saved: 'Back to saved',
  preparing: 'Start preparing',
  applied: 'Mark as applied',
  interviewing: 'Got an interview',
  offer: 'Got an offer',
  rejected: 'Mark as rejected',
  withdrawn: 'Withdraw',
}
