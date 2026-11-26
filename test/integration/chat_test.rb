require "test_helper"

class ChatTest < ActionDispatch::IntegrationTest
  test "chat page shows the greeting" do
    get chat_path
    assert_response :success
    assert_select ".message-assistant", text: /blog assistant/
  end

  test "sending a message streams the reply" do
    Post.create!(title: "Hello", body: "World")
    get chat_path

    post chat_messages_path, params: { message: { content: "list posts" } }, as: :turbo_stream
    assert_response :success
    assert_includes response.body, "list posts"
    assert_includes response.body, "Hello"
    assert_includes response.body, "intent: list_posts"

    get chat_path
    assert_select ".message-user", 1
  end

  test "new conversation clears the history" do
    post chat_messages_path, params: { message: { content: "hi" } }
    follow_redirect!
    assert_select ".message-user", 1

    delete chat_path
    follow_redirect!
    assert_select ".message-user", 0
  end
end
