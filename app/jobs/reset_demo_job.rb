# Rebuilds the shared demo account every night (config/recurring.yml), so what
# visitors added or changed is gone the next day. Does nothing on a server
# without a demo account; create it with bin/rails evidex:demo:reset.
class ResetDemoJob < ApplicationJob
  queue_as :default

  def perform
    Demo::Account.reset! if Demo::Account.user
  end
end
