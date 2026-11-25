class UpdatePostTool < MCP::Tool
  tool_name "update_post"
  description "Update the title and/or body of an existing blog post."
  input_schema(
    properties: { id: { type: "integer" }, title: { type: "string" }, body: { type: "string" } },
    required: [ "id" ]
  )

  def self.call(id:, title: nil, body: nil, server_context: nil)
    post = Post.find_by(id: id)
    return MCP::Tool::Response.new([ { type: "text", text: "Post #{id} not found" } ], error: true) unless post

    if post.update({ title: title, body: body }.compact)
      MCP::Tool::Response.new([ { type: "text", text: PostSerializer.call(post).to_json } ])
    else
      MCP::Tool::Response.new([ { type: "text", text: post.errors.full_messages.to_sentence } ], error: true)
    end
  end
end
