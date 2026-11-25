class CreatePostTool < MCP::Tool
  tool_name "create_post"
  description "Create a new blog post."
  input_schema(
    properties: { title: { type: "string" }, body: { type: "string" } },
    required: [ "title", "body" ]
  )

  def self.call(title:, body:, server_context: nil)
    post = Post.new(title: title, body: body)
    if post.save
      MCP::Tool::Response.new([ { type: "text", text: PostSerializer.call(post).to_json } ])
    else
      MCP::Tool::Response.new([ { type: "text", text: post.errors.full_messages.to_sentence } ], error: true)
    end
  end
end
