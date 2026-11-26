module Chatbot
  # Multinomial Naive Bayes intent classifier, trained from
  # config/chatbot/training_data.yml and saved to storage/chatbot/model.json.
  class Classifier
    MODEL_PATH = Rails.root.join("storage/chatbot/model.json")
    TRAINING_DATA_PATH = Rails.root.join("config/chatbot/training_data.yml")
    MUTEX = Mutex.new

    # Additive (Laplace/Lidstone) smoothing. 1.0 is the textbook default, but with
    # a vocabulary this large it flattens the scores, so short messages such as "hi"
    # got only ~30% confidence. A small value lets one known word be decisive.
    SMOOTHING = 0.1

    Prediction = Data.define(:intent, :confidence, :scores)

    class << self
      def training_examples(path = TRAINING_DATA_PATH)
        YAML.load_file(path).fetch("intents").transform_values do |intent|
          Array(intent.fetch("examples")).map(&:to_s)
        end
      end

      def train(examples, **options)
        new(**options).train(examples)
      end

      def load(path = MODEL_PATH, **options)
        data = JSON.parse(File.read(path))
        new(token_counts: data.fetch("token_counts"), example_counts: data.fetch("example_counts"), **options)
      end

      # The trained model, retrained automatically when the training data is newer
      # than the saved model and reloaded when `chatbot:train` writes a new one.
      def current
        MUTEX.synchronize do
          @current = nil if stale?
          @current ||= load_or_train
        end
      end

      private
        def stale?
          @current.nil? || !File.exist?(MODEL_PATH) || File.mtime(MODEL_PATH) != @model_mtime
        end

        def load_or_train
          if !File.exist?(MODEL_PATH) || File.mtime(TRAINING_DATA_PATH) > File.mtime(MODEL_PATH)
            train(training_examples).save
          end
          @model_mtime = File.mtime(MODEL_PATH)
          load
        end
    end

    attr_reader :example_counts

    def initialize(token_counts: {}, example_counts: {}, smoothing: SMOOTHING)
      @token_counts = token_counts
      @example_counts = example_counts
      @smoothing = smoothing
      refresh_stats
    end

    def train(examples)
      examples.each do |intent, phrases|
        counts = @token_counts[intent] ||= {}
        phrases.each do |phrase|
          @example_counts[intent] = @example_counts.fetch(intent, 0) + 1
          Features.call(phrase).each { |token| counts[token] = counts.fetch(token, 0) + 1 }
        end
      end
      refresh_stats
      self
    end

    def predict(text)
      tokens = Features.call(text).select { |token| @vocabulary.include?(token) }
      return Prediction.new(intent: nil, confidence: 0.0, scores: {}) unless meaningful?(tokens)

      log_scores = @token_counts.to_h do |intent, counts|
        denominator = @totals[intent] + @smoothing * @vocabulary.size
        [ intent, tokens.sum { |token| Math.log((counts.fetch(token, 0) + @smoothing) / denominator) } ]
      end

      max = log_scores.values.max
      weights = log_scores.transform_values { |score| Math.exp(score - max) }
      total = weights.values.sum
      scores = weights.transform_values { |weight| weight / total }.sort_by { |_, p| -p }.to_h
      intent, confidence = scores.first
      Prediction.new(intent:, confidence:, scores:)
    end

    def intents
      @token_counts.keys
    end

    def to_h
      {
        "version" => 1,
        "trained_at" => Time.current.iso8601,
        "example_counts" => @example_counts,
        "token_counts" => @token_counts
      }
    end

    def save(path = MODEL_PATH)
      FileUtils.mkdir_p(File.dirname(path))
      tmp_path = "#{path}.tmp"
      File.write(tmp_path, JSON.pretty_generate(to_h))
      File.rename(tmp_path, path)
      self
    end

    private
      def refresh_stats
        @vocabulary = @token_counts.values.flat_map(&:keys).to_set
        @totals = @token_counts.transform_values { |counts| counts.values.sum }
      end

      # Requires at least one known single word (not just a word pair), so input
      # made of unseen vocabulary is reported as not understood.
      def meaningful?(tokens)
        tokens.any? { |token| !token.include?("_") }
      end
  end
end
