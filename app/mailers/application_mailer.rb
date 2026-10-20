class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Evidex <no-reply@evidex.local>")
  layout "mailer"
end
