module Chatbot
  # Turns a user message into a reply: classifies the intent, extracts entities,
  # asks follow-up questions for missing details, and performs post actions
  # through the same tool classes the MCP server exposes.
  class Bot
    CONFIDENCE_THRESHOLD = 0.5
    LIST_LIMIT = 10

    CANCEL = /\A\s*(?:cancel|stop|never\s*mind|forget\s+it|no|nope|nah)\s*[.!]*\s*\z/i
    YES = /\A\s*(?:y|yes|yeah|yep|sure|ok|okay|confirm|do it|delete it|go ahead|absolutely)\b/i
    NO = /\A\s*(?:n|no|nope|nah|don'?t|keep it|leave it|cancel|stop|abort)\b/i

    GREETING = "Hi! I'm the blog assistant. I can list, show, search, count, create, update and delete posts. Type \"help\" to see examples."
    HELP = <<~TEXT.strip
      Here are some things you can ask me:
      • list posts, or show the latest 5 posts
      • show post 3, or open the latest post
      • find posts about rails
      • how many posts are there?
      • create a post titled "Hello" with body "My first post", or just: create a post
      • rename post 3 to A better title
      • change the body of post 3 to New text
      • delete post 3
      Type "cancel" to stop any step.
    TEXT
    GOODBYE = "Goodbye! Come back any time."
    THANKS = "You're welcome!"
    OUT_OF_SCOPE = "I can only help with this blog's posts. Type \"help\" to see what I can do."
    FALLBACK = "Sorry, I didn't understand that. Type \"help\" to see examples."
    NOTHING_PENDING = "There's nothing to confirm right now. Type \"help\" to see what I can do."
    WHICH_POST = "Which post? Tell me its number, for example \"post 3\". Say \"list posts\" to see them."

    def initialize(chat, classifier: Classifier.current)
      @chat = chat
      @classifier = classifier
      @state = chat.state.deep_dup
    end

    # Returns the saved [user_message, assistant_message].
    def respond(text)
      entities = EntityExtractor.call(text)
      pending = @state["pending"]
      reply = continue(pending, text, entities) if pending

      if reply
        intent, confidence = pending, nil
      else
        @state = {}
        prediction = @classifier.predict(text)
        intent, confidence = prediction.intent, prediction.confidence
        reply = understood?(prediction) ? dispatch(prediction.intent, entities) : FALLBACK
      end

      Chat.transaction do
        user_message = @chat.messages.create!(role: "user", content: text, intent:, confidence:)
        reply_message = @chat.messages.create!(role: "assistant", content: reply)
        @chat.update!(state: @state)
        [ user_message, reply_message ]
      end
    end

    private
      def understood?(prediction)
        prediction.intent && prediction.confidence >= CONFIDENCE_THRESHOLD
      end

      def dispatch(intent, entities)
        case intent
        when "greeting" then GREETING
        when "goodbye" then GOODBYE
        when "thanks" then THANKS
        when "help" then HELP
        when "out_of_scope" then OUT_OF_SCOPE
        when "confirm", "deny" then NOTHING_PENDING
        when "list_posts" then entities.query ? search(entities.query) : list_posts(entities.limit)
        when "count_posts" then count_posts
        when "search_posts" then search(entities.query)
        when "create_post" then start_create(entities)
        when "show_post", "update_post", "delete_post" then with_post(intent, entities)
        else FALLBACK
        end
      end

      # Handles a reply to the bot's last question. Returns nil when the message
      # isn't an answer, so it is classified as a new request instead.
      def continue(pending, text, entities)
        return confirm_delete(text) if pending == "confirm_delete"
        return cancel if text.match?(CANCEL)

        case pending
        when "create_post" then continue_create(text)
        when "select_post" then continue_select(entities)
        when "update_post" then continue_update(entities)
        when "search_posts" then search(text.strip)
        end
      end

      def cancel
        @state = {}
        "Okay, cancelled."
      end

      # --- Reading

      def list_posts(limit)
        _error, posts = call_tool(ListPostsTool, limit: limit || LIST_LIMIT)
        return "There are no posts yet. Say \"create a post\" to write one." if posts.empty?

        heading = posts.one? ? "Here is the latest post:" : "Here are the latest #{posts.size} posts:"
        [ heading, *posts.map { |post| "##{post['id']} #{post['title']}" } ].join("\n")
      end

      def count_posts
        count = Post.count
        "There #{count == 1 ? 'is' : 'are'} #{count} #{'post'.pluralize(count)}."
      end

      def search(query)
        if query.blank?
          @state = { "pending" => "search_posts" }
          return "What should I search for?"
        end

        @state = {}
        pattern = "%#{Post.sanitize_sql_like(query)}%"
        posts = Post.where("title ILIKE :pattern OR body ILIKE :pattern", pattern:)
          .order(created_at: :desc).limit(LIST_LIMIT)
        return "No posts mention \"#{query}\"." if posts.empty?

        [ "Posts matching \"#{query}\":", *posts.map { |post| "##{post.id} #{post.title}" } ].join("\n")
      end

      def show(post)
        "##{post.id} #{post.title}\n#{post.created_at.to_fs(:long)}\n\n#{post.body.truncate(800)}"
      end

      # --- Choosing a post for show, update and delete

      def with_post(action, entities)
        ref = entities.post_ref || (entities.title unless action == "update_post")
        unless ref
          @state = { "pending" => "select_post", "action" => action }
          @state.merge!({ "title" => entities.title, "body" => entities.body }.compact) if action == "update_post"
          return WHICH_POST
        end

        post = find_post(ref)
        return "I couldn't find #{describe(ref)}. Say \"list posts\" to see what's there." unless post

        case action
        when "show_post" then show(post)
        when "update_post" then start_update(post, entities)
        when "delete_post" then ask_delete(post)
        end
      end

      def continue_select(entities)
        action = @state["action"]
        return unless entities.post_ref || (entities.title && action != "update_post")

        carried = entities.with(title: entities.title || @state["title"], body: entities.body || @state["body"])
        @state = {}
        with_post(action, carried)
      end

      def find_post(ref)
        case ref
        when Integer then Post.find_by(id: ref)
        when :latest then Post.order(created_at: :desc).first
        when :oldest then Post.order(:created_at).first
        when String
          Post.where("LOWER(title) = ?", ref.downcase).first ||
            Post.where("title ILIKE ?", "%#{Post.sanitize_sql_like(ref)}%").order(created_at: :desc).first
        end
      end

      def describe(ref)
        case ref
        when Integer then "post ##{ref}"
        when String then "a post titled \"#{ref}\""
        else "any posts"
        end
      end

      # --- Creating

      def start_create(entities)
        @state = { "pending" => "create_post", "title" => entities.title, "body" => entities.body }.compact
        next_create_step
      end

      def continue_create(text)
        @state[@state["title"] ? "body" : "title"] = text.strip
        next_create_step
      end

      def next_create_step
        return "Sure! What should the title be? (Type \"cancel\" to stop.)" unless @state["title"]
        return "Got it. What should the post say?" unless @state["body"]

        title, body = @state.values_at("title", "body")
        @state = {}
        error, result = call_tool(CreatePostTool, title:, body:)
        error ? "I couldn't create the post: #{result}" : "Created post ##{result['id']} \"#{result['title']}\"."
      end

      # --- Updating

      def start_update(post, entities)
        changes = { title: entities.title, body: entities.body }.compact
        return apply_update(post, changes) if changes.any?

        @state = { "pending" => "update_post", "post_id" => post.id }
        "What should I change in post ##{post.id} \"#{post.title}\"? " \
          "Say for example \"title to A new title\" or \"body to New text\"."
      end

      def continue_update(entities)
        post = Post.find_by(id: @state["post_id"])
        return cancel_with("That post no longer exists.") unless post

        changes = { title: entities.title, body: entities.body }.compact
        return "Please tell me the new title or body, for example \"title to A new title\". Type \"cancel\" to stop." if changes.empty?

        apply_update(post, changes)
      end

      def apply_update(post, changes)
        @state = {}
        error, result = call_tool(UpdatePostTool, id: post.id, **changes)
        return "I couldn't update the post: #{result}" if error

        updated = changes.keys.map { |field| field == :title ? "title is now \"#{result['title']}\"" : "body was updated" }
        "Updated post ##{post.id}: #{updated.to_sentence}."
      end

      # --- Deleting

      def ask_delete(post)
        @state = { "pending" => "confirm_delete", "post_id" => post.id }
        "Delete post ##{post.id} \"#{post.title}\"? This can't be undone. Reply yes or no."
      end

      def confirm_delete(text)
        if text.match?(YES)
          id = @state["post_id"]
          @state = {}
          error, result = call_tool(DeletePostTool, id:)
          error ? "I couldn't delete the post: #{result}" : "Deleted post ##{id}."
        elsif text.match?(NO)
          cancel_with("Okay, I kept the post.")
        else
          "Please reply yes to delete the post, or no to keep it."
        end
      end

      def cancel_with(message)
        @state = {}
        message
      end

      # Runs an MCP tool and returns [error?, parsed JSON or plain text].
      def call_tool(tool, **arguments)
        response = tool.call(**arguments)
        text = response.content.first[:text]
        data = begin
          JSON.parse(text)
        rescue JSON::ParserError
          text
        end
        [ response.error?, data ]
      end
  end
end
