class DeletePostTool < MCP::Tool
  tool_name "delete_post"
  description "Delete a blog post by id."
  input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])

  def self.call(id:, server_context: nil)
    post = Post.find_by(id: id)
    return MCP::Tool::Response.new([ { type: "text", text: "Post #{id} not found" } ], error: true) unless post

    post.destroy!
    MCP::Tool::Response.new([ { type: "text", text: "Deleted post #{id}" } ])
  end
end
