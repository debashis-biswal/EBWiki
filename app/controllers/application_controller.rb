# frozen_string_literal: true

# application controller
class ApplicationController < ActionController::Base
  include Pundit

  before_action :store_user_location!, if: :storable_location?
  before_action :set_cache_headers
  rescue_from ActionController::InvalidAuthenticityToken, with: :clear_session_and_log
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  if Rails.env.staging?
    http_basic_authenticate_with name: ENV['STAGING_USERNAME'], password: ENV['STAGING_PASSWORD']
  end

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception, prepend: true
  before_action :set_paper_trail_whodunnit
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :state_objects
  before_action :set_paper_trail_whodunnit

  helper_method :mailbox, :conversation

  def info_for_paper_trail
    # Save additional info
    { ip: request.remote_ip }
  end

  def user_for_paper_trail
    # Save the user responsible for the action
    user_signed_in? ? current_user.id : 'Guest'
  end

  def default_url_options
    { host: ENV.fetch('HOST', 'localhost:3000') }
  end

  private

  def clear_session_and_log(exception)
    Rails.logger.error exception
    Rollbar.error exception.message
    cookies.delete(:_eb_wiki_session)
    cookies.delete(:ahoy_visit)
    session.delete(:ahoy_visitor)
    @current_user = nil
    flash[:error] = 'Oops, you got logged out. If this keeps happening please contact us. Thank you!'
    redirect_to '/'
  end

  def set_cache_headers
    response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'
  end

  def state_objects
    @state_objects ||= SortCollectionOrdinally.call(collection: State.all)
  end

  def storable_location?
    request.get? && is_navigational_format? && !devise_controller? && !request.xhr?
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
  end

  def user_not_authorized
    flash[:alert] = 'You are not authorized to perform this action.'
    redirect_to(request.referrer || root_path)
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit(:name, :description, :subscribed, :email, :password, :password_confirmation)
    end
    devise_parameter_sanitizer.permit(:account_update) do |u|
      u.permit(:name, :description, :subscribed, :email, :password, :password_confirmation)
    end
  end
end
