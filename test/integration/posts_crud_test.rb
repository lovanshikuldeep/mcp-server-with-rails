require "test_helper"

class PostsCrudTest < ActionDispatch::IntegrationTest
  test "full CRUD cycle" do
    get root_path
    assert_response :success

    assert_difference("Post.count", 1) do
      post posts_path, params: { post: { title: "Hello", body: "World" } }
    end
    created = Post.last
    assert_redirected_to post_path(created)

    get posts_path
    assert_select "h2", text: "Hello"

    get post_path(created)
    assert_response :success

    patch post_path(created), params: { post: { title: "Updated", body: "World" } }
    assert_redirected_to post_path(created)
    assert_equal "Updated", created.reload.title

    assert_no_difference("Post.count") do
      post posts_path, params: { post: { title: "", body: "" } }
    end
    assert_response :unprocessable_content

    assert_difference("Post.count", -1) do
      delete post_path(created)
    end
    assert_redirected_to posts_path
  end
end
