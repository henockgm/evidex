import type { Document } from '../api/client'

export const kindLabels: Record<Document['kind'], string> = {
  cv: 'CV',
  project: 'Project',
  certificate: 'Certificate',
  reference: 'Reference',
  other: 'Other',
}

export const documentStatusLabels: Record<Document['status'], string> = {
  pending: 'Waiting to be read',
  processing: 'Reading…',
  ready: 'Ready',
  failed: 'Could not read',
}

export const ACCEPT = '.pdf,.docx,.md,.markdown,.txt,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document,text/markdown,text/plain'
export const MAX_BYTES = 10 * 1024 * 1024

export function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

export const libraryQueryKey = ['documents'] as const
