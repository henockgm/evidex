import { useEffect, useState } from 'react'
import { fetchStatus, type ApiStatus } from './api/status'

type State =
  | { kind: 'loading' }
  | { kind: 'ready'; status: ApiStatus }
  | { kind: 'error'; message: string }

function App() {
  const [state, setState] = useState<State>({ kind: 'loading' })

  useEffect(() => {
    fetchStatus()
      .then((status) => setState({ kind: 'ready', status }))
      .catch((error: unknown) =>
        setState({ kind: 'error', message: error instanceof Error ? error.message : 'Unknown error' }),
      )
  }, [])

  return (
    <main className="container">
      <h1>Evidex</h1>
      <p className="tagline">Evidence-based job applications.</p>

      <section aria-label="API status" className="status">
        {state.kind === 'loading' && <p>Checking API…</p>}
        {state.kind === 'error' && <p role="alert">API unavailable: {state.message}</p>}
        {state.kind === 'ready' && (
          <dl>
            <dt>API</dt>
            <dd>{state.status.api_version}</dd>
            <dt>Database</dt>
            <dd>{state.status.database}</dd>
            <dt>Environment</dt>
            <dd>{state.status.environment}</dd>
          </dl>
        )}
      </section>
    </main>
  )
}

export default App
