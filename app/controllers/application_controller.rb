class ApplicationController < ActionController::API
  # include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  # stale_when_importmap_changes
  rescue_from StandardError, with: :standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActiveRecord::RecordNotUnique, with: :record_not_unique
  rescue_from ActiveRecord::RecordNotDestroyed, with: :record_not_destroyed

  private
    def record_not_found(e)
      render json: { error: e.message }, status: :not_found
    end
    def record_invalid(e)
      render json: { error: e.message }, status: :unprocessable_entity
    end
    def record_not_unique(e)
      render json: { error: e.message }, status: :unprocessable_entity
    end
    def record_not_destroyed(e)
      render json: { error: e.message }, status: :unprocessable_entity
    end
    def standard_error(e)
      render json: { error: e.message }, status: :internal_server_error
    end
end
