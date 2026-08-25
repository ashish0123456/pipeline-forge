class ApplicationController < ActionController::Base
  include Pundit::Authorization
  before_action :authenticate_user!
  protect_from_forgery with: :exception
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  private

  def not_found
    render json: { error: "Resource not found" }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def authenticate_user!
    return if current_user

    respond_to do |format|
      format.html { redirect_to login_path, alert: "Please sign in to continue." }
      format.json { render json: { error: "Authentication required" }, status: :unauthorized }
    end
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = if session[:user_id]
      User.find_by(id: session[:user_id])
    else
      ApiToken.authenticate(request.authorization.to_s.delete_prefix("Bearer "))
    end
  end
  helper_method :current_user

  def pundit_user
    current_user
  end

  def forbidden
    render json: { error: "Forbidden" }, status: :forbidden
  end
end
