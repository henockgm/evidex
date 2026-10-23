import type { AuditEvent } from '../api/client'

export const activityLabels: Record<AuditEvent['action'], string> = {
  registered: 'Account created',
  registration_duplicate: 'Someone tried to create an account with your email',
  signed_in: 'Signed in',
  sign_in_failed: 'Failed sign-in attempt',
  account_locked: 'Account locked after failed attempts',
  signed_out: 'Signed out',
  session_revoked: 'Device signed out',
  other_sessions_revoked: 'All other devices signed out',
  email_verified: 'Email address confirmed',
  password_reset_requested: 'Password reset requested',
  password_reset: 'Password reset',
  password_changed: 'Password changed',
  identity_linked: 'Account connected',
  identity_unlinked: 'Account disconnected',
  oauth_signed_in: 'Signed in',
  second_factor_failed: 'Wrong two-factor code',
  two_factor_enabled: 'Two-factor sign-in turned on',
  two_factor_disabled: 'Two-factor sign-in turned off',
  recovery_codes_regenerated: 'Recovery codes replaced',
  reauthenticated: "Confirmed it's you",
  reauthentication_failed: "Failed to confirm it's you",
  admin_locked: 'Account locked by an administrator',
  admin_unlocked: 'Account unlocked by an administrator',
  admin_signed_out: 'Signed out on all devices by an administrator',
}

/** Events worth a second look if the user doesn't recognise them. */
export const warningActions = new Set<AuditEvent['action']>([
  'registration_duplicate',
  'sign_in_failed',
  'account_locked',
  'second_factor_failed',
  'reauthentication_failed',
  'admin_locked',
])

const providerLabels: Record<string, string> = { google_oauth2: 'Google', entra_id: 'Microsoft', password: 'password' }

const dateTime = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })

export function activityDetail({ details }: AuditEvent): string | null {
  const parts: string[] = []
  const via = details.method ?? details.provider
  if (via) parts.push(`with ${providerLabels[via] ?? via}`)
  if (details.second_factor === 'recovery_code') parts.push('using a recovery code')
  if (details.until) parts.push(`until ${dateTime.format(new Date(details.until))}`)
  return parts.length ? parts.join(' ') : null
}
