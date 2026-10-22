/** Only same-site paths, so a ?next= link can't send someone to another site. */
export function safeNext(next: string | null) {
  return next?.startsWith('/') && !next.startsWith('//') ? next : '/'
}
