module Api
  module V1
    module Me
      # Turning two-factor sign-in on and off, and replacing recovery codes.
      class TwoFactorsController < BaseController
        limit_requests to: 10, within: 5.minutes, by: -> { Current.user&.id || request.remote_ip }

        # Step 1: a new secret to scan. Kept in the encrypted Rails session until confirmed.
        def setup
          return render_problem(:conflict, "Already on", detail: "Two-factor sign-in is already turned on.") if Current.user.two_factor_enabled?

          secret = ROTP::Base32.random
          session[:otp_setup_secret] = secret
          uri = Current.user.totp(secret).provisioning_uri(Current.user.email_address)
          svg = RQRCode::QRCode.new(uri).as_svg(module_size: 4, use_path: true, viewbox: true)
          render json: { secret:, otpauth_uri: uri, qr_code: "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}" }
        end

        # Step 2: confirm with a code from the app; returns the recovery codes once.
        def create
          secret = session[:otp_setup_secret]
          return render_problem(:unprocessable_content, "Start again", detail: "Set up two-factor sign-in again.") if secret.blank?
          unless Current.user.verify_otp!(params.require(:code), secret:)
            return render_problem(:unprocessable_content, "Validation failed", errors: { code: [ "Code is incorrect or expired" ] })
          end

          codes = Current.user.enable_two_factor!(secret)
          session.delete(:otp_setup_secret)
          AuditEvent.record(:two_factor_enabled, user: Current.user, request:)
          render json: { user: UserSerializer.new(Current.user), recovery_codes: codes }, status: :created
        end

        # Needs a current authenticator or recovery code.
        def destroy
          return render_problem(:conflict, "Already off", detail: "Two-factor sign-in is off.") unless Current.user.two_factor_enabled?
          return invalid_code unless Current.user.verify_second_factor!(params.require(:code).to_s)

          Current.user.disable_two_factor!
          AuditEvent.record(:two_factor_disabled, user: Current.user, request:)
          render json: { user: UserSerializer.new(Current.user) }
        end

        def recovery_codes
          return render_problem(:conflict, "Two-factor sign-in is off") unless Current.user.two_factor_enabled?
          return invalid_code unless Current.user.verify_otp!(params.require(:code))

          codes = RecoveryCode.regenerate_for!(Current.user)
          AuditEvent.record(:recovery_codes_regenerated, user: Current.user, request:)
          render json: { user: UserSerializer.new(Current.user), recovery_codes: codes }
        end

        private
          def invalid_code
            render_problem :unprocessable_content, "Validation failed", errors: { code: [ "Code is incorrect or expired" ] }
          end
      end
    end
  end
end
