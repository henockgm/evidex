const messages: Record<string, string> = {
  account_exists:
    'An account with this email already exists. Sign in with your password, then connect the provider under Security settings.',
  identity_taken: 'That account is already connected to a different Evidex user.',
  provider_already_linked: 'You already have an account from this provider connected.',
  email_missing: "The provider didn't share an email address, so we can't create an account.",
  reauthentication_failed:
    "That didn't confirm it's you. Use the Google or Microsoft account connected to Evidex, or your password and code if you have them.",
  account_suspended: 'This account is locked. Contact the person who runs this Evidex site.',
  oauth_failed: 'Sign-in was cancelled or failed. Please try again.',
  invalid_response: 'Sign-in was cancelled or failed. Please try again.',
}

export function oauthErrorMessage(code: string | null): string | null {
  if (!code) return null
  return messages[code] ?? messages.oauth_failed
}
