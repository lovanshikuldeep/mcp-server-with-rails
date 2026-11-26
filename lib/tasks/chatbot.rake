namespace :chatbot do
  desc "Train the intent classifier from config/chatbot/training_data.yml"
  task train: :environment do
    examples = Chatbot::Classifier.training_examples
    Chatbot::Classifier.train(examples).save
    puts "Trained on #{examples.values.sum(&:size)} examples across #{examples.size} intents."
    puts "Saved model to #{Chatbot::Classifier::MODEL_PATH.relative_path_from(Rails.root)}"
  end

  desc "Measure accuracy with leave-one-out cross-validation"
  task evaluate: :environment do
    pairs = Chatbot::Classifier.training_examples.flat_map { |intent, phrases| phrases.map { |phrase| [ intent, phrase ] } }

    misses = pairs.each_with_index.filter_map do |(intent, phrase), index|
      rest = pairs.reject.with_index { |_, other| other == index }
        .group_by(&:first).transform_values { |group| group.map(&:last) }
      predicted = Chatbot::Classifier.train(rest).predict(phrase).intent
      [ phrase, intent, predicted ] unless predicted == intent
    end

    accuracy = 100.0 * (pairs.size - misses.size) / pairs.size
    puts format("Leave-one-out accuracy: %.1f%% (%d/%d)", accuracy, pairs.size - misses.size, pairs.size)
    misses.each { |phrase, expected, got| puts "  #{phrase.inspect}: expected #{expected}, got #{got || 'unknown'}" }
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
