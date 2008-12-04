require 'test/unit'
require 'open3'
require 'shellwords'
require_relative 'ruby/envutil'

class TestOpen3 < Test::Unit::TestCase
  RUBY = EnvUtil.rubybin

  def test_exit_status
    Open3.popen3(RUBY, '-e', 'exit true') {|i,o,e,t|
      assert_equal(true, t.value.success?)
    }
    Open3.popen3(RUBY, '-e', 'exit false') {|i,o,e,t|
      assert_equal(false, t.value.success?)
    }
  end

  def test_stdin
    Open3.popen3(RUBY, '-e', 'exit STDIN.gets.chomp == "t"') {|i,o,e,t|
      i.puts 't'
      assert_equal(true, t.value.success?)
    }
    Open3.popen3(RUBY, '-e', 'exit STDIN.gets.chomp == "t"') {|i,o,e,t|
      i.puts 'f'
      assert_equal(false, t.value.success?)
    }
  end

  def test_stdout
    Open3.popen3(RUBY, '-e', 'STDOUT.print "foo"') {|i,o,e,t|
      assert_equal("foo", o.read)
    }
  end

  def test_stderr
    Open3.popen3(RUBY, '-e', 'STDERR.print "bar"') {|i,o,e,t|
      assert_equal("bar", e.read)
    }
  end

  def test_block
    r = Open3.popen3(RUBY, '-e', 'STDOUT.print STDIN.read') {|i,o,e,t|
      i.print "baz"
      i.close
      assert_equal("baz", o.read)
      "qux"
    }
    assert_equal("qux", r)
  end

  def test_noblock
    i,o,e,t = Open3.popen3(RUBY, '-e', 'STDOUT.print STDIN.read')
    i.print "baz"
    i.close
    assert_equal("baz", o.read)
  ensure
    i.close if !i.closed?
    o.close if !o.closed?
    e.close if !e.closed?
  end

  def test_commandline
    commandline = Shellwords.join([RUBY, '-e', 'print "quux"'])
    Open3.popen3(commandline) {|i,o,e,t|
      assert_equal("quux", o.read)
    }
  end

  def test_pid
    Open3.popen3(RUBY, '-e', 'print $$') {|i,o,e,t|
      pid = o.read.to_i
      assert_equal(pid, t[:pid])
      assert_equal(pid, t.pid)
    }
  end

  def with_pipe
    r, w = IO.pipe
    yield r, w
  ensure
    r.close if !r.closed?
    w.close if !w.closed?
  end

  def with_reopen(io, arg)
    old = io.dup
    io.reopen(arg)
    yield old
  ensure
    io.reopen(old)
    old.close if old && !old.closed?
  end

  def test_popen2
    with_pipe {|r, w|
      with_reopen(STDERR, w) {|old|
        w.close
        Open3.popen2(RUBY, '-e', 's=STDIN.read; STDOUT.print s+"o"; STDERR.print s+"e"') {|i,o,t|
          assert_kind_of(Thread, t)
          i.print "z"
          i.close
          STDERR.reopen(old)
          assert_equal("zo", o.read)
          assert_equal("ze", r.read)
        }
      }
    }
  end

  def test_popen2e
    with_pipe {|r, w|
      with_reopen(STDERR, w) {|old|
        w.close
        Open3.popen2e(RUBY, '-e', 's=STDIN.read; STDOUT.print s+"o"; STDOUT.flush; STDERR.print s+"e"') {|i,o,t|
          assert_kind_of(Thread, t)
          i.print "y"
          i.close
          STDERR.reopen(old)
          assert_equal("yoye", o.read)
          assert_equal("", r.read)
        }
      }
    }
  end

  def test_pipeline_rw
    Open3.pipeline_rw([RUBY, '-e', 'print STDIN.read + "1"'],
                      [RUBY, '-e', 'print STDIN.read + "2"']) {|i,o,ts|
      assert_kind_of(IO, i)
      assert_kind_of(IO, o)
      assert_kind_of(Array, ts)
      assert_equal(2, ts.length)
      ts.each {|t| assert_kind_of(Thread, t) }
      i.print "0"
      i.close
      assert_equal("012", o.read)
      ts.each {|t|
        assert(t.value.success?)
      }
    }
  end

  def test_pipeline_r
    Open3.pipeline_r([RUBY, '-e', 'print "1"'],
                     [RUBY, '-e', 'print STDIN.read + "2"']) {|o,ts|
      assert_kind_of(IO, o)
      assert_kind_of(Array, ts)
      assert_equal(2, ts.length)
      ts.each {|t| assert_kind_of(Thread, t) }
      assert_equal("12", o.read)
      ts.each {|t|
        assert(t.value.success?)
      }
    }
  end

  def test_pipeline_w
    command = [RUBY, '-e', 's=STDIN.read; print s[1..-1]; exit s[0] == ?t']
    str = 'ttftff'
    Open3.pipeline_w(*[command]*str.length) {|i,ts|
      assert_kind_of(IO, i)
      assert_kind_of(Array, ts)
      assert_equal(str.length, ts.length)
      ts.each {|t| assert_kind_of(Thread, t) }
      i.print str
      i.close
      ts.each_with_index {|t, i|
        assert_equal(str[i] == ?t, t.value.success?)
      }
    }
  end

end