import { useEffect, useRef, type ReactNode } from 'react'
import { Link } from 'react-router'
import type { JobPostingSummary } from '../api/client'
import { statusLabels } from '../applications/labels'
import { Alert } from '../components/ui'
import { formatDate } from './labels'

/** Names the postings already saved for the same job ad, each with a link to open it. */
export function DuplicateWarning({ duplicates, children }: { duplicates: JobPostingSummary[]; children?: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    ref.current?.scrollIntoView?.({ block: 'nearest', behavior: 'smooth' })
  }, [duplicates])

  return (
    <div ref={ref}>
      <Alert tone="warning">
        <p className="font-semibold">
          {duplicates.length === 1 ? "You've already saved this job ad:" : "You've already saved this job ad more than once:"}
        </p>
        <ul className="mt-2 space-y-1">
          {duplicates.map((posting) => (
            <li key={posting.id}>
              <Link to={`/postings/${posting.id}`} target="_blank" className="font-medium underline">
                {posting.title} at {posting.company}
              </Link>{' '}
              · {statusLabels[posting.status]} · added {formatDate(posting.created_at.slice(0, 10))}
            </li>
          ))}
        </ul>
        {children}
      </Alert>
    </div>
  )
}
