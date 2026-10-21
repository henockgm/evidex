import type { ApplicationStatus } from '../api/client'

export const statusLabels: Record<ApplicationStatus, string> = {
  saved: 'Saved',
  preparing: 'Preparing',
  applied: 'Applied',
  interviewing: 'Interviewing',
  offer: 'Offer',
  accepted: 'Accepted',
  rejected: 'Rejected',
  no_response: 'No response',
  withdrawn: 'Withdrawn',
}

/** Wording for the button that moves an application to a status. */
export const transitionLabels: Record<ApplicationStatus, string> = {
  saved: 'Back to saved',
  preparing: 'Start preparing',
  applied: 'Mark as applied',
  interviewing: 'Got an interview',
  offer: 'Got an offer',
  accepted: 'Accept the offer',
  rejected: 'Mark as rejected',
  no_response: 'Mark as no response',
  withdrawn: 'Withdraw',
}
