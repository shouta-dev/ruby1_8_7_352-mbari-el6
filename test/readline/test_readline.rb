begin
  require "readline"
=begin
  class << Readline
    [
     "vi_editing_mode",
     "emacs_editing_mode",
     "completion_append_character=",
     "completion_append_character",
     "basic_word_break_characters=",
     "basic_word_break_characters",
     "completer_word_break_characters=",
     "completer_word_break_characters",
     "basic_quote_characters=",
     "basic_quote_characters",
     "completer_quote_characters=",
     "completer_quote_characters",
     "filename_quote_characters=",
     "filename_quote_characters",
    ].each do |method_name|
      define_method(method_name.to_sym) do |*args|
        raise NotImplementedError
      end
    end
  end
=end
rescue LoadError
else
  require "test/unit"
  require "tempfile"
end

class TestReadline < Test::Unit::TestCase
  def teardown
    Readline.instance_variable_set("@completion_proc", nil)
  end
  
  def test_safe_level_4
    method_args =
      [
       ["readline"],
       ["input=", $stdin],
       ["output=", $stdout],
       ["completion_proc=", proc {}],
       ["completion_proc"],
       ["completion_case_fold=", true],
       ["completion_case_fold"],
       ["vi_editing_mode"],
       ["emacs_editing_mode"],
       ["completion_append_character=", "s"],
       ["completion_append_character"],
       ["basic_word_break_characters=", "s"],
       ["basic_word_break_characters"],
       ["completer_word_break_characters=", "s"],
       ["completer_word_break_characters"],
       ["basic_quote_characters=", "\\"],
       ["basic_quote_characters"],
       ["completer_quote_characters=", "\\"],
       ["completer_quote_characters"],
       ["filename_quote_characters=", "\\"],
       ["filename_quote_characters"],
      ]
    method_args.each do |method_name, *args|
      assert_raises(SecurityError, NotImplementedError,
                    "method=<#{method_name}>") do
        Thread.start {
          $SAFE = 4
          Readline.send(method_name.to_sym, *args)
          assert(true)
        }.join
      end
    end
  end

  def test_readline
    stdin = Tempfile.new("test_readline_stdin")
    stdout = Tempfile.new("test_readline_stdout")
    begin
      stdin.write("hello\n")
      stdin.close
      stdout.close
      line = replace_stdio(stdin.path, stdout.path) {
        Readline.readline("> ", true)
      }
      assert_equal("hello", line)
      assert_equal(true, line.tainted?)
      stdout.open
      assert_equal("> ", stdout.read(2))
      assert_equal(1, Readline::HISTORY.length)
      assert_equal("hello", Readline::HISTORY[0])
      assert_raises(SecurityError) do
        Thread.start {
          $SAFE = 1
          replace_stdio(stdin.path, stdout.path) do
            Readline.readline("> ".taint)
          end
        }.join
      end
      assert_raises(SecurityError) do
        Thread.start {
          $SAFE = 4
          replace_stdio(stdin.path, stdout.path) { Readline.readline("> ") }
        }.join
      end
    ensure
      stdin.close(true)
      stdout.close(true)
    end
  end if !/EditLine/n.match(Readline::VERSION)

  def test_input=
    assert_raise(TypeError) do
      Readline.input = "This is not a file."
    end
  end
  
  def test_output=
    assert_raise(TypeError) do
      Readline.output = "This is not a file."
    end
  end

  def test_completion_proc
    expected = proc { |input| input }
    Readline.completion_proc = expected
    assert_equal(expected, Readline.completion_proc)

    assert_raise(ArgumentError) do
      Readline.completion_proc = "This does not have call method."
    end
  end

  def test_completion_case_fold
    expected = [true, false, "string", {"a" => "b"}]
    expected.each do |e|
      Readline.completion_case_fold = e
      assert_equal(e, Readline.completion_case_fold)
    end
  end

  def test_completion_append_character
    begin
      Readline.completion_append_character = "x"
      assert_equal("x", Readline.completion_append_character)
      Readline.completion_append_character = "xyz"
      assert_equal("x", Readline.completion_append_character)
      Readline.completion_append_character = nil
      assert_equal(nil, Readline.completion_append_character)
      Readline.completion_append_character = ""
      assert_equal(nil, Readline.completion_append_character)
    rescue NotImplementedError
    end
  end

  # basic_word_break_characters
  # completer_word_break_characters
  # basic_quote_characters
  # completer_quote_characters
  # filename_quote_characters
  def test_some_characters_methods
    method_names = [
                    "basic_word_break_characters",
                    "completer_word_break_characters",
                    "basic_quote_characters",
                    "completer_quote_characters",
                    "filename_quote_characters",
                   ]
    method_names.each do |method_name|
      begin
        begin
          saved = Readline.send(method_name.to_sym)
          expecteds = [" ", " .,|\t", ""]
          expecteds.each do |e|
            Readline.send((method_name + "=").to_sym, e)
            assert_equal(e, Readline.send(method_name.to_sym))
          end
        ensure
          Readline.send((method_name + "=").to_sym, saved) if saved
        end
      rescue NotImplementedError
      end
    end
  end

  private

  def replace_stdio(stdin_path, stdout_path)
    open(stdin_path, "r"){|stdin|
      open(stdout_path, "w"){|stdout|
        orig_stdin = STDIN.dup
        orig_stdout = STDOUT.dup
        STDIN.reopen(stdin)
        STDOUT.reopen(stdout)
        begin
          Readline.input = STDIN
          Readline.output = STDOUT
          yield
        ensure
          STDIN.reopen(orig_stdin)
          STDOUT.reopen(orig_stdout)
          orig_stdin.close
          orig_stdout.close
        end
      }
    }
  end
end if defined?(::Readline)
