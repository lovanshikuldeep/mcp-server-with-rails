class ListPostsTool < MCP::Tool
  tool_name "list_posts"
  description "List blog posts, newest first."
  input_schema(
    properties: {
      limit: { type: "integer", description: "Max posts to return (default 20)" }
    }
  )

  def self.call(limit: 20, server_context: nil)
    posts = Post.order(created_at: :desc).limit(limit.to_i.clamp(1, 100))
    MCP::Tool::Response.new([ { type: "text", text: posts.map { |p| PostSerializer.call(p) }.to_json } ])
  end
end
