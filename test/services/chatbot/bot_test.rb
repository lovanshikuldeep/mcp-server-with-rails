require "test_helper"

class Chatbot::BotTest < ActiveSupport::TestCase
  CLASSIFIER = Chatbot::Classifier.train(Chatbot::Classifier.training_examples)

  setup do
    @chat = Chat.create!
    @post = Post.create!(title: "Rails tips", body: "Use the console often")
  end

  def say(text)
    Chatbot::Bot.new(@chat.reload, classifier: CLASSIFIER).respond(text).last.content
  end

  test "saves both messages with the detected intent" do
    say "list posts"
    user, reply = @chat.messages.order(:id)

    assert_equal "user", user.role
    assert_equal "list_posts", user.intent
    assert_operator user.confidence, :>=, Chatbot::Bot::CONFIDENCE_THRESHOLD
    assert_equal "assistant", reply.role
  end

  test "lists, counts, searches and shows posts" do
    assert_includes say("list posts"), "##{@post.id} Rails tips"
    assert_equal "There is 1 post.", say("how many posts are there")
    assert_includes say("find posts about console"), "Rails tips"
    assert_includes say("show post #{@post.id}"), "Use the console often"
  end

  test "creates a post in one message" do
    assert_difference("Post.count") do
      assert_match(/Created post #\d+ "Hello"/, say('create a post titled "Hello" with body "World"'))
    end
  end

  test "asks for missing details when creating a post" do
    assert_match(/title/, say("create a new post"))
    assert_match(/say/, say("My trip"))
    assert_difference("Post.count") { say("It was great") }
    assert_equal "It was great", Post.find_by!(title: "My trip").body
  end

  test "cancel stops a multi-step action" do
    say "create a post"
    assert_equal "Okay, cancelled.", say("cancel")
    assert_equal({}, @chat.reload.state)
  end

  test "updates a post" do
    assert_match(/title is now "Better tips"/, say("rename post #{@post.id} to Better tips"))
    assert_equal "Better tips", @post.reload.title
  end

  test "asks what to change, then updates" do
    assert_match(/What should I change/, say("edit post #{@post.id}"))
    say "body to Shorter text"
    assert_equal "Shorter text", @post.reload.body
  end

  test "asks which post when none is given" do
    assert_equal Chatbot::Bot::WHICH_POST, say("delete a post")
    assert_match(/Delete post ##{@post.id}/, say(@post.id.to_s))
  end

  test "an unrelated reply to 'which post' is handled as a new request" do
    say "delete a post"
    assert_includes say("list posts"), "Rails tips"
  end

  test "delete needs confirmation" do
    assert_match(/This can't be undone/, say("delete post #{@post.id}"))
    assert_no_difference("Post.count") { assert_match(/kept/, say("no")) }

    say "delete post #{@post.id}"
    assert_difference("Post.count", -1) { say("yes") }
  end

  test "reports missing posts" do
    assert_match(/couldn't find post #999999/, say("show post 999999"))
  end

  test "falls back when it does not understand" do
    assert_equal Chatbot::Bot::FALLBACK, say("zxcv qwerty")
    assert_equal Chatbot::Bot::OUT_OF_SCOPE, say("what's the weather like")
  end
end
