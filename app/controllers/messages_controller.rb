class MessagesController < ApplicationController
  MAX_LENGTH = 2000

  # POST /chat/messages
  def create
    content = params.expect(message: [ :content ])[:content].to_s.strip.first(MAX_LENGTH)
    return redirect_to(chat_path, status: :see_other) if content.empty?

    @user_message, @reply = Chatbot::Bot.new(current_chat).respond(content)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to chat_path, status: :see_other }
    end
  end
end
