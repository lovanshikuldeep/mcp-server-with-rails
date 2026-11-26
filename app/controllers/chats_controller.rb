class ChatsController < ApplicationController
  # GET /chat
  def show
    @chat = current_chat
    @messages = @chat.messages.order(:created_at, :id)
  end

  # DELETE /chat
  def destroy
    session.delete(:chat_id)
    redirect_to chat_path, status: :see_other
  end
end
