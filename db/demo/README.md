# Demo account data

Everything here is fictional. `Demo::Account.reset!` (run daily and by
`bin/rails evidex:demo:reset`) rebuilds the shared demo account from these files:

- `cv.md`, `projects.md` – the demo person's career library
- `postings.yml` – job postings with requirements and application progress
- `match_report.yml` – a match report for the first posting, produced once by the
  real report generator and saved, so resets don't call the AI
