require "test_helper"

class Chatbot::EntityExtractorTest < ActiveSupport::TestCase
  def extract(text) = Chatbot::EntityExtractor.call(text)

  test "post references" do
    assert_equal 3, extract("show post 3").post_ref
    assert_equal 4, extract("delete #4").post_ref
    assert_equal 7, extract("7").post_ref
    assert_equal :latest, extract("open the latest post").post_ref
    assert_equal :oldest, extract("delete the first post").post_ref
  end

  test "list limit is not mistaken for a post id" do
    result = extract("show me the 5 posts")
    assert_equal 5, result.limit
    assert_nil result.post_ref
  end

  test "quoted title and body" do
    result = extract('create a post titled "Hello world" with body "My first post"')
    assert_equal "Hello world", result.title
    assert_equal "My first post", result.body
    assert_equal "create a post titled with body", result.command_text
  end

  test "unquoted title and body" do
    result = extract("create a post titled Rails tips with body Use the console often")
    assert_equal "Rails tips", result.title
    assert_equal "Use the console often", result.body
  end

  test "new title and body for updates" do
    assert_equal "Better title", extract("rename post 3 to Better title").title
    assert_equal "How to code", extract("change the body of post 3 to How to code").body
    assert_equal "Fresh", extract("title to Fresh").title
    assert_equal 3, extract("rename post 3 to Better title").post_ref
  end

  test "words like 'to' inside a new post body are not treated as an update" do
    result = extract("create a post with body how to code")
    assert_equal "how to code", result.body
  end

  test "search terms" do
    assert_equal "rails", extract("find posts about rails").query
    assert_equal "docker", extract("search for docker?").query
    assert_nil extract("search posts").query
  end
end
