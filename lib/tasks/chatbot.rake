namespace :chatbot do
  desc "Train the intent classifier from config/chatbot/training_data.yml"
  task train: :environment do
    examples = Chatbot::Classifier.training_examples
    Chatbot::Classifier.train(examples).save
    puts "Trained on #{examples.values.sum(&:size)} examples across #{examples.size} intents."
    puts "Saved model to #{Chatbot::Classifier::MODEL_PATH.relative_path_from(Rails.root)}"
  end

  desc "Measure accuracy with leave-one-out cross-validation (optional SMOOTHING=0.1)"
  task evaluate: :environment do
    smoothing = Float(ENV.fetch("SMOOTHING", Chatbot::Classifier::SMOOTHING))
    threshold = Chatbot::Bot::CONFIDENCE_THRESHOLD
    pairs = Chatbot::Classifier.training_examples.flat_map { |intent, phrases| phrases.map { |phrase| [ intent, phrase ] } }

    wrong = []
    unsure = []
    pairs.each_with_index do |(intent, phrase), index|
      rest = pairs.reject.with_index { |_, other| other == index }
        .group_by(&:first).transform_values { |group| group.map(&:last) }
      prediction = Chatbot::Classifier.train(rest, smoothing:).predict(phrase)

      if prediction.intent != intent
        wrong << [ phrase, intent, prediction.intent ]
      elsif prediction.confidence < threshold
        unsure << [ phrase, intent, prediction.confidence ]
      end
    end

    total = pairs.size
    percent = ->(count) { format("%.1f%% (%d/%d)", 100.0 * count / total, count, total) }
    puts "Smoothing: #{smoothing}"
    puts "Right intent:                     #{percent.(total - wrong.size)}"
    puts "Right intent and >= #{(threshold * 100).round}% confident: #{percent.(total - wrong.size - unsure.size)}  <- what users actually get answered"
    wrong.each { |phrase, expected, got| puts "  wrong:  #{phrase.inspect}: expected #{expected}, got #{got || 'unknown'}" }
    unsure.each { |phrase, expected, confidence| puts "  unsure: #{phrase.inspect}: #{expected} but only #{(confidence * 100).round}% confident" }
  end

  desc 'Classify a sentence, e.g. bin/rails chatbot:predict TEXT="show post 3"'
  task predict: :environment do
    text = ENV.fetch("TEXT") { abort 'Usage: bin/rails chatbot:predict TEXT="show post 3"' }
    prediction = Chatbot::Classifier.current.predict(text)
    entities = Chatbot::EntityExtractor.call(text)

    puts "Intent: #{prediction.intent || 'unknown'} (#{(prediction.confidence * 100).round}%)"
    prediction.scores.first(3).each { |intent, score| puts format("  %-14s %5.1f%%", intent, score * 100) }
    puts "Entities: #{entities.to_h.except(:command_text).compact}"
  end
end
