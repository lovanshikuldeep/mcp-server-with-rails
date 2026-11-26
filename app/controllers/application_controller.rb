class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def current_chat
      @current_chat ||= Chat.find_by(id: session[:chat_id]) || Chat.create!.tap { |chat| session[:chat_id] = chat.id }
    end
end
