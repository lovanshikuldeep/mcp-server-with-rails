require "test_helper"

class ChatsHelperTest < ActionView::TestCase
  test "links post references" do
    assert_includes format_chat_message("See #12"), %(<a href="/posts/12">#12</a>)
  end

  test "escapes HTML without linking escaped characters" do
    html = format_chat_message(%(I'm <b>bold</b>))
    assert_includes html, "I&#39;m &lt;b&gt;bold&lt;/b&gt;"
    assert_not_includes html, "<a"
  end

  test "keeps line breaks" do
    assert_includes format_chat_message("one\ntwo"), "one\n<br />two"
  end
end
