module Chatbot
  # Pulls post references, titles, bodies, search terms and list limits out of a
  # message. Whatever is left (command_text) is what the classifier sees, so free
  # text such as a post title doesn't confuse intent detection.
  class EntityExtractor
    Result = Data.define(:post_ref, :title, :body, :query, :limit, :command_text)

    QUOTED = /["“]([^"“”]+)["”]/
    EDIT_VERB = /\b(?:change|set|update|edit|replace|make)\b/
    BODY_TO = /(?:\A\s*(?:the\s+|new\s+)?|#{EDIT_VERB}.*?\b)(?:body|content|text)\b.*?\bto\s+(.+)\z/im
    TITLE_TO = /(?:\A\s*(?:the\s+|new\s+)?title\b|\b(?:rename|retitle)\b|#{EDIT_VERB}.*?\btitle\b).*?\bto\s+(.+)\z/im
    BODY = /(?:\b(?:with|and)\s+(?:the\s+|a\s+)?(?:body|content|text)(?:\s+is|\s*:)?|\b(?:body|content|text)(?:\s+is|\s*:)|\bsaying)\s+(.+)\z/im
    TITLE = /\b(?:titled|called|named|title\s+is|title\s*:)\s*(.+?)(?=\s*,?\s+(?:and|with)\s+(?:the\s+|a\s+)?(?:body|content|text)\b|\s*\z)/im
    QUERY = /.*\b(?:about|containing|mentioning|matching|regarding|search(?:\s+for)?|look(?:ing)?\s+for)\s+(.+)\z/im
    GENERIC_QUERY = /\A(?:the\s+|all\s+)?(?:posts?|articles?|blogs?)\z/i
    POST_ID = /(?:\b(?:post|article|blog|entry|id|number)\s*#?\s*|#)(\d+)\b/i
    LIMIT = /\b(\d+)\s+(?:posts|articles|blogs|entries)\b/i
    LATEST = /\b(?:latest|newest|last|most\s+recent|recent)\b/i
    OLDEST = /\b(?:first|oldest|earliest)\b/i

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text.to_s.strip
    end

    def call
      quoted = @text.scan(QUOTED).flatten.map(&:strip)
      text = @text.gsub(QUOTED, " ")
      title = body = query = nil

      if quoted.any?
        title, body = quoted
        query = quoted.first
      else
        body, text = take(text, BODY_TO)
        title, text = take(text, TITLE_TO)
        body, text = take(text, BODY) unless body
        title, text = take(text, TITLE) unless title
        found, rest = take(text, QUERY, trim: true)
        query, text = found, rest if found && !found.match?(GENERIC_QUERY)
      end

      limit = text[LIMIT, 1]&.to_i
      Result.new(post_ref: post_ref(text, limit), title:, body:, query:, limit:, command_text: text.squish)
    end

    private
      def take(text, pattern, trim: false)
        match = text.match(pattern)
        return [ nil, text ] unless match

        value = match[1].strip
        value = value.sub(/[.!?]+\z/, "") if trim
        [ value.presence, text[0...match.begin(1)] + text[match.end(1)..] ]
      end

      def post_ref(text, limit)
        if (id = text[POST_ID, 1])
          id.to_i
        elsif text.match?(LATEST)
          :latest
        elsif text.match?(OLDEST)
          :oldest
        elsif limit.nil? && (numbers = text.scan(/\b\d+\b/)).one?
          numbers.first.to_i
        end
      end
  end
end
