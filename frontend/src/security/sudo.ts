import { createContext, useContext } from 'react'
import { ApiError } from '../api/client'

/** Problem type the API returns when a sensitive change needs a fresh sign-in. */
export const REAUTHENTICATION_REQUIRED = 'urn:evidex:problem:reauthentication-required'

export function needsReauthentication(error: unknown) {
  return error instanceof ApiError && error.problem?.type === REAUTHENTICATION_REQUIRED
}

export class ReauthenticationCancelled extends Error {
  constructor() {
    super("Nothing was changed because you didn't confirm it's you.")
  }
}

/** Runs a request; if the API asks the user to confirm it's them, asks, then runs it again. */
export type WithSudo = <T>(request: () => Promise<T>) => Promise<T>

export const SudoContext = createContext<WithSudo | null>(null)

export function useSudo(): WithSudo {
  const withSudo = useContext(SudoContext)
  if (!withSudo) throw new Error('useSudo needs a <SudoProvider>')
  return withSudo
}
