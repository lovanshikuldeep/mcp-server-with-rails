require "test_helper"

class Chatbot::ClassifierTest < ActiveSupport::TestCase
  setup do
    @classifier = Chatbot::Classifier.train(Chatbot::Classifier.training_examples)
  end

  test "classifies sentences that are not in the training data" do
    {
      "could you list every post" => "list_posts",
      "how many articles do we have" => "count_posts",
      "find posts about hotwire" => "search_posts",
      "please show post 12" => "show_post",
      'write a new post titled "Ruby"' => "create_post",
      "rename post 2 to Something else" => "update_post",
      "please remove post 4" => "delete_post",
      "hello friend" => "greeting",
      "thank you very much" => "thanks"
    }.each do |text, intent|
      assert_equal intent, @classifier.predict(text).intent, "for #{text.inspect}"
    end
  end

  test "reports unknown input" do
    prediction = @classifier.predict("zxcv qwerty")
    assert_nil prediction.intent
    assert_equal 0.0, prediction.confidence
  end

  test "scores are probabilities sorted by likelihood" do
    scores = @classifier.predict("list posts").scores
    assert_in_delta 1.0, scores.values.sum, 0.0001
    assert_equal scores.values.sort.reverse, scores.values
  end

  test "saves and loads the trained model" do
    path = Rails.root.join("tmp/chatbot_model_test.json")
    @classifier.save(path)
    loaded = Chatbot::Classifier.load(path)

    assert_equal @classifier.intents.sort, loaded.intents.sort
    assert_equal @classifier.predict("delete post 3").intent, loaded.predict("delete post 3").intent
  ensure
    FileUtils.rm_f(path)
  end
end
