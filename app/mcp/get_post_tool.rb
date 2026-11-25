class GetPostTool < MCP::Tool
  tool_name "get_post"
  description "Get a single blog post by id."
  input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])

  def self.call(id:, server_context: nil)
    post = Post.find_by(id: id)
    return MCP::Tool::Response.new([ { type: "text", text: "Post #{id} not found" } ], error: true) unless post

    MCP::Tool::Response.new([ { type: "text", text: PostSerializer.call(post).to_json } ])
  end
end
