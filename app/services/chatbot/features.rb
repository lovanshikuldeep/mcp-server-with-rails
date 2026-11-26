module Chatbot
  # Turns a message into classifier features: meaningful lowercase words plus
  # word pairs, each counted once. Used for both training and prediction.
  module Features
    STOPWORDS = %w[a an the is are am be to of i me my your this that and or in on at please can could would will].to_set.freeze
    SYNONYMS = {
      "article" => "post", "articles" => "posts",
      "entry" => "post", "entries" => "posts",
      "blogs" => "posts"
    }.freeze

    def self.call(text)
      words = EntityExtractor.call(text).command_text.downcase
        .gsub(/\d+/, " numtoken ")
        .scan(/[a-z']+/)
        .map { |word| word.delete("'") }
        .map { |word| SYNONYMS.fetch(word, word) }
        .reject { |word| word.empty? || STOPWORDS.include?(word) }

      (words + words.each_cons(2).map { |pair| pair.join("_") }).uniq
    end
  end
end
