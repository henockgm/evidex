# Evidex

**Evidence-based job applications.** Evidex tracks job postings, matches each
requirement against your own career documents, and drafts applications that only
claim what you can back up with a citation.

> Status: early development (milestone M0, foundations). Features below are planned.

## Planned features

- **Strong authentication**: email + password, Google and Microsoft sign-in,
  email verification, session management, rate limiting, TOTP two-factor auth
- **Job postings**: import from a URL (SSRF-safe fetching) or pasted text;
  AI extracts requirements, deadline, location and keywords
- **Career library**: upload CVs and project notes (PDF, DOCX, Markdown);
  chunked and embedded into PostgreSQL with pgvector
- **Match report (RAG)**: every requirement classified as *Evidenced*,
  *Transferable* or *Gap*, with citations to your own documents
- **Application tracking**: status pipeline, timeline, deadlines, dashboard

## Tech stack

| Layer | Choice |
|-------|--------|
| Backend | Ruby 4.0, Rails 8.1 (API mode) |
| Database | PostgreSQL 17 + pgvector |
| Jobs / cache / websockets | Solid Queue, Solid Cache, Solid Cable |
| API docs | OpenAPI 3 generated from request specs (rswag) |
| Frontend | React 19 + TypeScript + Vite, in [`frontend/`](frontend) |
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

Open http://localhost:5173. API documentation is at http://localhost:3000/api-docs.

### Tests and checks

```bash
bin/ci                            # everything CI runs: lint, types, security scans, tests
bundle exec rspec                 # backend tests
npm test --prefix frontend        # frontend tests
bin/rails rswag:specs:swaggerize  # regenerate swagger/v1/swagger.yaml
```

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/up` | Health check |
| GET | `/api/v1/status` | API and database status |

## License

[MIT](LICENSE)
