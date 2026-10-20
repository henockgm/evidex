import { useQuery } from '@tanstack/react-query'
import { getCsrfToken } from '../api/client'
import { useProviders } from '../auth/useProviders'

/**
 * OAuth must start with a full-page form POST (not fetch): the browser follows the
 * redirect to Google/Microsoft, and the CSRF token blocks login-CSRF attacks.
 */
export function OAuthButton({ path, children }: { path: string; children: React.ReactNode }) {
  const { data: token } = useQuery({ queryKey: ['csrf-token'], queryFn: getCsrfToken, staleTime: 0 })

  return (
    <form method="post" action={path}>
      <input type="hidden" name="authenticity_token" value={token ?? ''} />
      <button
        type="submit"
        disabled={!token}
        className="flex w-full items-center justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-slate-900 shadow-sm ring-1 ring-inset ring-slate-300 hover:bg-slate-50 disabled:opacity-60 dark:bg-slate-900 dark:text-slate-100 dark:ring-slate-700 dark:hover:bg-slate-800"
      >
        {children}
      </button>
    </form>
  )
}

export function OAuthButtons({ verb }: { verb: 'Sign in' | 'Sign up' }) {
  const { data: providers = [] } = useProviders()
  if (!providers.length) return null

  return (
    <div className="space-y-3">
      <div className="relative text-center text-xs uppercase text-slate-500">
        <span className="relative z-10 bg-white px-2 dark:bg-slate-900">or</span>
        <div className="absolute inset-x-0 top-1/2 border-t border-slate-200 dark:border-slate-800" />
      </div>
      {providers.map((provider) => (
        <OAuthButton key={provider.id} path={provider.path}>
          {verb} with {provider.label}
        </OAuthButton>
      ))}
    </div>
  )
}
