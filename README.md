# Evidex

**Evidence-based job applications.** Evidex tracks job postings, matches each
requirement against your own career documents, and drafts applications that only
claim what you can back up with a citation.

> Status: early development. Authentication (M1) is done; job postings and application tracking (M2) are in review; the career library and AI matching come next.

## Features

- **Strong authentication** (done): email + password, Google and Microsoft sign-in,
  email verification, password reset, device/session management, rate limiting
  and account lockout. Two-factor auth is planned.
- **Job postings** (done): add by pasting text or importing a link (SSRF-safe
  fetching that reads schema.org `JobPosting` data); edit everything, keep a
  requirements list per posting
- **AI extraction** (done): Claude reads the ad in a background job and fills in
  empty fields, requirements and keywords, using structured outputs; never
  overwrites what the user entered; per-user daily limit and token usage tracking
- **Application tracking** (done): status pipeline with a timeline, applied date,
  next action, notes, links and contacts; filters, search, sorting, pagination;
  a dashboard with counts per status, upcoming deadlines and next actions
- **Admin area** (done): accounts with search, lock/unlock and sign-out
  everywhere, the security audit log across accounts, and AI calls, tokens and
  estimated cost per account; admins never see users' documents, postings or
  reports

Planned:

- **Career library**: upload CVs and project notes (PDF, DOCX, Markdown);
  chunked and embedded into PostgreSQL with pgvector
- **Match report (RAG)**: every requirement classified as *Evidenced*,
  *Transferable* or *Gap*, with citations to your own documents

## Tech stack

| Layer | Choice |
|-------|--------|
| Backend | Ruby 4.0, Rails 8.1 (API mode) |
| Database | PostgreSQL 17 + pgvector |
| Jobs / cache / websockets | Solid Queue, Solid Cache, Solid Cable |
| API docs | OpenAPI 3 generated from request specs (rswag) |
| Auth | `has_secure_password` (bcrypt), OmniAuth (Google, Microsoft Entra ID), Rails rate limiting |
| AI | Anthropic Ruby SDK, Claude with structured outputs, run in Active Job background jobs |
| Frontend | React 19 + TypeScript + Vite, React Router, TanStack Query, Tailwind CSS, in [`frontend/`](frontend) |
| API client | Typed with `openapi-typescript` + `openapi-fetch`, generated from the OpenAPI spec |
| Tests | RSpec, FactoryBot, WebMock, SimpleCov; Vitest + Testing Library |
| Quality | RuboCop (Rails Omakase), Brakeman, bundler-audit, oxlint, npm audit |
| CI | GitHub Actions |

## Architecture

```
Browser ──► Vite dev server :5173 ──/api, /auth──► Rails API :3000 ──► PostgreSQL + pgvector
                 (React SPA)                         │
                                                     └──► Solid Queue jobs ──► LLM / embeddings APIs
```

The SPA and the API share one origin (Vite proxies in development; Rails serves
the built SPA in production), so authentication uses secure `HttpOnly` session
cookies rather than tokens in browser storage.

## Authentication and security design

- **Server-side sessions.** The browser gets a random token in a signed `HttpOnly`,
  `SameSite=Lax` cookie (`Secure` in production). Only its SHA-256 digest is stored,
  so a database leak doesn't expose usable sessions. Sessions expire after 14 days
  idle or 30 days total, and users can see and revoke every signed-in device.
- **CSRF protection.** Every state-changing request needs the `X-CSRF-Token` header
  (from `GET /api/v1/csrf_token`). The Rails session is reset on sign-in to prevent
  session fixation.
- **No account enumeration.** Sign-in, registration and password reset respond
  identically whether or not an email is registered; the real owner gets an email.
- **Brute-force defence.** Per-IP rate limits on sensitive endpoints, plus per-account
  lockout after 5 failures (15 minutes, doubling up to 24 hours) with an email alert.
- **Password rules.** 12+ characters, bcrypt's 72-byte limit enforced, and passwords
  found in known breaches are rejected via the Have I Been Pwned range API
  (k-anonymity: only 5 characters of the SHA-1 hash leave the server).
- **Single-use, short-lived tokens.** Password reset links expire in 15 minutes and
  stop working once the password changes; email confirmation links expire in 24 hours.
  The SPA removes tokens from the address bar after reading them.
- **Safe Google/Microsoft linking.** OAuth starts with a CSRF-protected POST, never a
  GET link. An identity links to an existing account by email only when the provider
  says the email is verified (Google). Microsoft's email claim isn't guaranteed
  verified, so it never auto-links. When a verified Google sign-in claims an account
  whose email was never confirmed, that account's password and sessions are removed
  (pre-account-takeover defence).
- **Re-authentication.** Changing the password requires the current one; adding a
  first password to a Google/Microsoft-only account requires a sign-in within the
  last 10 minutes. Users can't remove their last sign-in method.
- **Audit trail.** Sign-ins, failures, lockouts, resets and linking are recorded.
- **Admin area.** Admin rights are granted only from the server
  (`bin/rails "evidex:admin:grant[email]"`), never through the API. The admin API
  answers 404 to everyone else and requires two-factor sign-in; locking, unlocking
  and signing out an account also need a sign-in from the last 10 minutes. Every
  admin action is recorded and shown on the affected user's activity page. Admin
  endpoints return account metadata only, and specs check that admins can't read
  anyone's documents, postings or reports.
- **Errors** follow RFC 9457 problem details (`application/problem+json`).

## Getting started

### Prerequisites

- Ruby 4.0.7 (see `.ruby-version`; e.g. `mise install`)
- PostgreSQL 17 with the [pgvector](https://github.com/pgvector/pgvector) extension
- Node.js 26 (see `frontend/.nvmrc`)

On macOS with Homebrew:

```bash
brew install mise postgresql@17 pgvector
brew services start postgresql@17
mise install
```

### Setup and run

```bash
bin/setup        # installs gems + npm packages, prepares the database, starts the app
bin/dev          # starts Rails (:3000) and Vite (:5173)
```

Open http://localhost:5173. API documentation is at http://localhost:3000/api-docs,
and emails sent in development open at http://localhost:3000/letter_opener.

### Configuration

Copy `.env.example` to `.env`. Everything works without it, except Google and Microsoft
sign-in, which appear only once their credentials are set:

- **Google**: create an OAuth client ID (Web application) in Google Cloud Console →
  APIs & Services → Credentials. Authorized redirect URI:
  `http://localhost:5173/auth/google_oauth2/callback`. Set `GOOGLE_CLIENT_ID` and
  `GOOGLE_CLIENT_SECRET`.
- **Microsoft**: register an app in the Microsoft Entra admin center → App registrations,
  with "Accounts in any organizational directory and personal Microsoft accounts".
  Add a Web redirect URI `http://localhost:5173/auth/entra_id/callback` and a client
  secret. Set `MICROSOFT_CLIENT_ID` and `MICROSOFT_CLIENT_SECRET`.
- **AI features**: set `ANTHROPIC_API_KEY` (from console.anthropic.com). Optional:
  `EVIDEX_AI_MODEL` (default `claude-opus-5-5`) and `EVIDEX_AI_DAILY_LIMIT` (default 20).
  Without a key the app works normally and hides the AI buttons.

### Tests and checks

```bash
bin/ci                            # everything CI runs: lint, types, security scans, tests
bundle exec rspec                 # backend tests
npm test --prefix frontend        # frontend tests
bin/rails rswag:specs:swaggerize  # regenerate swagger/v1/swagger.yaml
npm run gen:api --prefix frontend # regenerate TypeScript API types from it
```

## API

The full, interactive reference is served at `/api-docs` (OpenAPI 3, generated from
the request specs). The frontend's API types are generated from the same file, and CI
fails if either drifts.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/csrf_token` | CSRF token for state-changing requests |
| GET | `/api/v1/auth/providers` | Enabled Google/Microsoft sign-in providers |
| POST | `/api/v1/registration` | Register with email and password |
| POST / DELETE | `/api/v1/session` | Sign in / sign out |
| POST | `/api/v1/email_verification` (`/resend`) | Confirm email / resend confirmation |
| POST / PATCH | `/api/v1/password_reset` | Request reset email / set new password |
| GET / DELETE | `/api/v1/me` | Current user / delete account |
| PATCH | `/api/v1/me/password` | Change or add a password |
| GET / DELETE | `/api/v1/me/sessions` (`/:id`, `/others`) | List and revoke signed-in devices |
| GET / DELETE | `/api/v1/me/identities` (`/:id`) | List and disconnect Google/Microsoft |
| POST | `/auth/:provider` | Start Google/Microsoft sign-in (browser form POST) |
| GET | `/up`, `/api/v1/status` | Health checks |

## License

[MIT](LICENSE)
