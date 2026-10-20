import { apiGet } from './client'

export interface ApiStatus {
  name: string
  api_version: string
  environment: string
  database: 'ok' | 'error'
  time: string
}

export const fetchStatus = () => apiGet<ApiStatus>('/status')
