class PostSerializer
  def self.call(post)
    { id: post.id, title: post.title, body: post.body, created_at: post.created_at, updated_at: post.updated_at }
  end
end
