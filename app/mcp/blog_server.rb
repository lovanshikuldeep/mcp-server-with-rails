class BlogServer
  TOOLS = [ ListPostsTool, GetPostTool, CreatePostTool, UpdatePostTool, DeletePostTool ].freeze

  def self.build
    MCP::Server.new(name: "mcp_with_blog", version: "1.0.0", tools: TOOLS)
  end
end
