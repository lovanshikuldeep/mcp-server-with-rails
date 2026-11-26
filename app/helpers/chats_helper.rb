module ChatsHelper
  POST_REFERENCE = /(#\d+\b)/

  # Escapes the message, links post references such as "#3" and keeps line breaks.
  def format_chat_message(text)
    parts = text.to_s.split(POST_REFERENCE).map do |part|
      part.match?(/\A#{POST_REFERENCE}\z/) ? link_to(part, post_path(part.delete("#"))) : part
    end
    simple_format(safe_join(parts), {}, sanitize: false)
  end
end
