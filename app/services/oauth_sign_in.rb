# Decides what a Google/Microsoft callback means: sign in, link to the signed-in
# user, link to an existing account, or create a new account.
#
# Security rules:
# - An identity links to an existing account by email only when the provider
#   asserts the email is verified (Google's email_verified claim). Microsoft's
#   email claim is not guaranteed verified, so it never auto-links.
# - When a verified Google email claims an account whose own email was never
#   verified, the account's password and sessions are removed, so whoever
#   registered that email with a password can't keep access ("pre-hijacking").
class OauthSignIn
  Result = Data.define(:user, :outcome, :error) do
    def success? = error.nil?
  end

  def initialize(auth:, current_user: nil)
    @auth = auth
    @current_user = current_user
  end

  def call
    return failure(:invalid_response) if provider.blank? || uid.blank?

    @current_user ? link_to_current_user : sign_in_or_register
  end

  private
    attr_reader :auth

    def link_to_current_user
      if identity
        return identity.user_id == @current_user.id ? success(@current_user, :already_linked) : failure(:identity_taken)
      end
      return failure(:provider_already_linked) if @current_user.identities.exists?(provider:)

      create_identity(@current_user)
      success(@current_user, :linked)
    end

    def sign_in_or_register
      if identity
        identity.update!(email:, email_verified:)
        return success(identity.user, :signed_in)
      end
      return failure(:email_missing) if email.blank?

      user = User.find_by(email_address: email)
      user ? link_by_verified_email(user) : register
    end

    def link_by_verified_email(user)
      return failure(:account_exists) unless email_verified

      User.transaction do
        unless user.verified?
          user.sessions.delete_all
          user.update_columns(password_digest: nil, updated_at: Time.current)
          user.verify_email!
        end
        create_identity(user)
      end
      success(user, :linked)
    end

    def register
      user = User.transaction do
        User.create!(email_address: email, name: auth.info&.name&.first(100),
          email_verified_at: (Time.current if email_verified)).tap { |new_user| create_identity(new_user) }
      end
      success(user, :registered)
    end

    def create_identity(user)
      user.identities.create!(provider:, uid:, email:, email_verified:)
    end

    def identity
      return @identity if defined?(@identity)

      @identity = Identity.find_by(provider:, uid:)
    end

    def provider = auth.provider.to_s
    def uid = auth.uid.to_s

    def email
      raw = auth.info&.email.presence || auth.info&.unverified_email.presence
      User.normalize_value_for(:email_address, raw) if raw
    end

    def email_verified
      provider == "google_oauth2" && ActiveModel::Type::Boolean.new.cast(auth.extra&.raw_info&.email_verified) == true
    end

    def success(user, outcome) = Result.new(user:, outcome:, error: nil)
    def failure(error) = Result.new(user: nil, outcome: nil, error:)
end
