import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router'
import { GuestOnly, RequireAuth } from './auth/guards'
import { Layout } from './components/Layout'
import { ActivityPage } from './pages/ActivityPage'
import { DashboardPage } from './pages/DashboardPage'
import { EditPostingPage } from './pages/EditPostingPage'
import { ForgotPasswordPage } from './pages/ForgotPasswordPage'
import { LibraryPage } from './pages/LibraryPage'
import { LoginPage } from './pages/LoginPage'
import { NewPostingPage } from './pages/NewPostingPage'
import { PostingPage } from './pages/PostingPage'
import { PostingsPage } from './pages/PostingsPage'
import { RegisterPage } from './pages/RegisterPage'
import { ResetPasswordPage } from './pages/ResetPasswordPage'
import { SecondFactorPage } from './pages/SecondFactorPage'
import { SecurityPage } from './pages/SecurityPage'
import { VerifyEmailPage } from './pages/VerifyEmailPage'

export function AppRoutes() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route element={<GuestOnly />}>
          <Route path="login" element={<LoginPage />} />
          <Route path="login/verify" element={<SecondFactorPage />} />
          <Route path="register" element={<RegisterPage />} />
          <Route path="forgot-password" element={<ForgotPasswordPage />} />
        </Route>
        <Route path="reset-password" element={<ResetPasswordPage />} />
        <Route path="verify-email" element={<VerifyEmailPage />} />
        <Route element={<RequireAuth />}>
          <Route index element={<DashboardPage />} />
          <Route path="postings" element={<PostingsPage />} />
          <Route path="postings/new" element={<NewPostingPage />} />
          <Route path="postings/:id" element={<PostingPage />} />
          <Route path="postings/:id/edit" element={<EditPostingPage />} />
          <Route path="library" element={<LibraryPage />} />
          <Route path="settings/security" element={<SecurityPage />} />
          <Route path="settings/activity" element={<ActivityPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false, refetchOnWindowFocus: false } },
})

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </QueryClientProvider>
  )
}
