import type { ReactNode } from 'react'
import { Link } from 'react-router'
import { CONTACT_EMAIL } from '../site'

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="space-y-2">
      <h2 className="text-base font-semibold">{title}</h2>
      <div className="space-y-2 text-sm leading-6 text-slate-700 dark:text-slate-300">{children}</div>
    </section>
  )
}

export function PrivacyPage() {
  return (
    <article className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Privacy</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">Last updated 30 October 2026</p>
      </div>

      <p className="text-sm leading-6 text-slate-700 dark:text-slate-300">
        Evidex is a personal portfolio project run by Henock Mullissa in Finland, who is responsible for the data described
        here. In short: your data is used only to run the app for you, it isn't sold, and there are no adverts or analytics.
      </p>

      <Section title="What's stored">
        <ul className="list-disc space-y-1 pl-5">
          <li>Your account: email address, name, and a hashed password. The 2FA secret is encrypted.</li>
          <li>What you add: job postings, applications, contacts, interviews, notes, and uploaded documents such as CVs.</li>
          <li>AI results: extracted requirements and match reports, with a count of AI runs to enforce the daily limit.</li>
          <li>Security records: signed-in devices, IP addresses, browser details and a log of account activity.</li>
        </ul>
        <p>
          Contacts you add may be other people, such as recruiters, so please only record what you need for your application.
        </p>
      </Section>

      <Section title="Why, and on what basis">
        <p>
          The data is used to provide the service you signed up for (GDPR Art. 6(1)(b)). Security records are kept to protect
          accounts, which is a legitimate interest (Art. 6(1)(f)).
        </p>
      </Section>

      <Section title="Who else handles it">
        <ul className="list-disc space-y-1 pl-5">
          <li>Hetzner hosts the app, database and uploads on a server in Finland.</li>
          <li>
            Anthropic, based in the United States, receives job posting text and relevant passages from your documents when you
            run an AI feature. AI features only run when you start them.
          </li>
          <li>Brevo delivers account and security emails, so it receives your email address.</li>
          <li>Cloudflare provides the site's DNS. Your traffic doesn't pass through it.</li>
          <li>
            Have I Been Pwned is checked when you choose a password. Only the first five characters of the password's hash are
            sent, never the password.
          </li>
          <li>If Google or Microsoft sign-in is offered and you use it, that provider confirms your identity to Evidex.</li>
        </ul>
        <p>Search over your documents runs on the Evidex server, so that step doesn't send your text to anyone.</p>
        <p>When you import a posting from a link, the Evidex server fetches that page from the website you named.</p>
      </Section>

      <Section title="Cookies">
        <p>
          Evidex uses only the cookies it needs: one keeps you signed in, one protects forms, and one recognises your browser so
          you can be told about sign-ins from new devices. There are no tracking cookies.
        </p>
      </Section>

      <Section title="How long it's kept">
        <p>
          Your data is kept until you delete it or your account. Deleting your account in{' '}
          <Link to="/settings/security" className="underline">
            Security settings
          </Link>{' '}
          removes your account and everything in it.
        </p>
      </Section>

      <Section title="Your rights">
        <p>
          You can ask to see, correct, export or delete your data, or object to how it's used. Email{' '}
          <a href={`mailto:${CONTACT_EMAIL}`} className="underline">
            {CONTACT_EMAIL}
          </a>
          . You can also complain to the Finnish Data Protection Ombudsman (tietosuoja.fi).
        </p>
      </Section>
    </article>
  )
}
