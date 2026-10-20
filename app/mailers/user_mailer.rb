class UserMailer < ApplicationMailer
  before_action { @user = params[:user] }

  default to: -> { @user.email_address }

  def email_verification
    @url = app_url("/verify-email", token: @user.generate_token_for(:email_verification))
    mail subject: "Confirm your email address for Evidex"
  end

  def password_reset
    @url = app_url("/reset-password", token: @user.password_reset_token)
    mail subject: "Reset your Evidex password"
  end

  def registration_attempt
    @sign_in_url = app_url("/login")
    @reset_url = app_url("/forgot-password")
    mail subject: "Someone tried to create an Evidex account with your email"
  end

  def account_locked
    @reset_url = app_url("/forgot-password")
    mail subject: "Your Evidex account is temporarily locked"
  end

  def password_changed
    @reset_url = app_url("/forgot-password")
    mail subject: "Your Evidex password was changed"
  end

  def identity_linked
    @provider_label = Evidex::OAUTH_PROVIDERS.dig(params[:provider].to_sym, :label)
    @settings_url = app_url("/settings/security")
    mail subject: "#{@provider_label} sign-in was connected to your Evidex account"
  end

  private
    def app_url(path, **query)
      url = "#{Rails.configuration.x.app_url}#{path}"
      query.any? ? "#{url}?#{query.to_query}" : url
    end
end
