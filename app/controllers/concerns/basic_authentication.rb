module BasicAuthentication
  extend ActiveSupport::Concern
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  included do
    before_action :authenticate_with_basic_auth
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :authenticate_with_basic_auth, **options
    end
  end

  private
    def authenticate_with_basic_auth
      expected_username = basic_auth_username
      expected_password = basic_auth_password

      if expected_username.blank? || expected_password.blank?
        Rails.logger.error("Basic authentication credentials are not configured")
        return render json: { error: "Basic authentication is not configured" },
          status: :internal_server_error
      end

      authenticate_or_request_with_http_basic do |username, password|
        secure_compare(username, expected_username) &&
          secure_compare(password, expected_password)
      end
    end

    def basic_auth_username
      ENV["BASIC_AUTH_USERNAME"].presence ||
        Rails.application.credentials.dig(:basic_auth, :username)
    end

    def basic_auth_password
      ENV["BASIC_AUTH_PASSWORD"].presence ||
        Rails.application.credentials.dig(:basic_auth, :password)
    end

    def secure_compare(value, expected)
      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(value.to_s),
        Digest::SHA256.hexdigest(expected.to_s)
      )
    end
end
