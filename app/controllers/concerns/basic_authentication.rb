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
      authenticate_or_request_with_http_basic do |username, password|
        secure_compare(username, ENV.fetch("BASIC_AUTH_USERNAME")) &&
          secure_compare(password, ENV.fetch("BASIC_AUTH_PASSWORD"))
      end
    end

    def secure_compare(value, expected)
      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(value.to_s),
        Digest::SHA256.hexdigest(expected.to_s)
      )
    end
end
