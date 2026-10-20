# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style: TypeScript", "npm run lint --prefix frontend"
  step "Docs: OpenAPI spec and API types", "bin/rails rswag:specs:swaggerize > /dev/null && npm run gen:api --prefix frontend"
  step "Types: TypeScript", "npm run typecheck --prefix frontend"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: npm audit", "npm audit --prefix frontend --audit-level=high"

  step "Tests: Rails", "bundle exec rspec"
  step "Tests: Frontend", "npm test --prefix frontend"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
