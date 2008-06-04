require 'test/unit'
require 'tmpdir'
require_relative 'envutil'

class TestProcess < Test::Unit::TestCase
  RUBY = EnvUtil.rubybin

  def setup
    Process.waitall
  end

  def teardown
    Process.waitall
  end

  def write_file(filename, content)
    File.open(filename, "w") {|f|
      f << content
    }
  end

  def with_tmpchdir
    Dir.mktmpdir {|d|
      Dir.chdir(d) {
        yield d
      }
    }
  end

  def run_in_child(str) # should be called in a temporary directory
    write_file("test-script", str)
    Process.wait spawn(RUBY, "test-script")
    $?
  end

  def test_rlimit_availability
    begin
      Process.getrlimit(nil)
    rescue NotImplementedError
      assert_raise(NotImplementedError) { Process.setrlimit }
    rescue TypeError
      assert_raise(ArgumentError) { Process.setrlimit }
    end
  end

  def rlimit_exist?
    Process.getrlimit(nil)
  rescue NotImplementedError
    return false
  rescue TypeError
    return true
  end

  def test_rlimit_nofile
    return unless rlimit_exist?
    with_tmpchdir {
      write_file 's', <<-"End"
	cur_nofile, max_nofile = Process.getrlimit(Process::RLIMIT_NOFILE)
	result = 1
	begin
	  Process.setrlimit(Process::RLIMIT_NOFILE, 0, max_nofile)
	rescue Errno::EINVAL
	  result = 0
	end
	if result == 1
	  begin
	    IO.pipe
	  rescue Errno::EMFILE
	   result = 0
	  end
	end
	Process.setrlimit(Process::RLIMIT_NOFILE, cur_nofile, max_nofile)
	exit result
      End
      pid = spawn RUBY, "s"
      Process.wait pid
      assert_equal(0, $?.to_i, "#{$?}")
    }
  end

  def test_rlimit_name
    return unless rlimit_exist?
    [
      :AS, "AS",
      :CORE, "CORE",
      :CPU, "CPU",
      :DATA, "DATA",
      :FSIZE, "FSIZE",
      :MEMLOCK, "MEMLOCK",
      :NOFILE, "NOFILE",
      :NPROC, "NPROC",
      :RSS, "RSS",
      :STACK, "STACK",
      :SBSIZE, "SBSIZE",
    ].each {|name|
      if Process.const_defined? "RLIMIT_#{name}"
        assert_nothing_raised { Process.getrlimit(name) }
      else
        assert_raise(ArgumentError) { Process.getrlimit(name) }
      end
    }
    assert_raise(ArgumentError) { Process.getrlimit(:FOO) }
    assert_raise(ArgumentError) { Process.getrlimit("FOO") }
  end

  def test_rlimit_value
    return unless rlimit_exist?
    assert_raise(ArgumentError) { Process.setrlimit(:CORE, :FOO) }
    assert_raise(Errno::EPERM) { Process.setrlimit(:NOFILE, :INFINITY) }
    assert_raise(Errno::EPERM) { Process.setrlimit(:NOFILE, "INFINITY") }
  end

  TRUECOMMAND = [RUBY, '-e', '']

  def test_execopts_opts
    assert_nothing_raised {
      Process.wait Process.spawn(*TRUECOMMAND, {})
    }
    assert_raise(ArgumentError) {
      Process.wait Process.spawn(*TRUECOMMAND, :foo => 100)
    }
    assert_raise(ArgumentError) {
      Process.wait Process.spawn(*TRUECOMMAND, Process => 100)
    }
  end

  def test_execopts_pgroup
    assert_nothing_raised { system(*TRUECOMMAND, :pgroup=>false) }

    io = IO.popen([RUBY, "-e", "print Process.getpgrp"])
    assert_equal(Process.getpgrp.to_s, io.read)
    io.close

    io = IO.popen([RUBY, "-e", "print Process.getpgrp", :pgroup=>true])
    assert_equal(io.pid.to_s, io.read)
    io.close

    assert_raise(ArgumentError) { system(*TRUECOMMAND, :pgroup=>-1) }
    assert_raise(Errno::EPERM) { Process.wait spawn(*TRUECOMMAND, :pgroup=>2) }

    io1 = IO.popen([RUBY, "-e", "print Process.getpgrp", :pgroup=>true])
    io2 = IO.popen([RUBY, "-e", "print Process.getpgrp", :pgroup=>io1.pid])
    assert_equal(io1.pid.to_s, io1.read)
    assert_equal(io1.pid.to_s, io2.read)
    Process.wait io1.pid
    Process.wait io2.pid
    io1.close
    io2.close
  end

  def test_execopts_rlimit
    return unless rlimit_exist?
    assert_raise(ArgumentError) { system(*TRUECOMMAND, :rlimit_foo=>0) }
    assert_raise(ArgumentError) { system(*TRUECOMMAND, :rlimit_NOFILE=>0) }
    assert_raise(ArgumentError) { system(*TRUECOMMAND, :rlimit_nofile=>[]) }
    assert_raise(ArgumentError) { system(*TRUECOMMAND, :rlimit_nofile=>[1,2,3]) }

    max = Process.getrlimit(:CORE).last

    n = max
    IO.popen([RUBY, "-e",
             "p Process.getrlimit(:CORE)", :rlimit_core=>n]) {|io|
      assert_equal("[#{n}, #{n}]\n", io.read)
    }

    n = 0
    IO.popen([RUBY, "-e",
             "p Process.getrlimit(:CORE)", :rlimit_core=>n]) {|io|
      assert_equal("[#{n}, #{n}]\n", io.read)
    }

    n = max
    IO.popen([RUBY, "-e",
             "p Process.getrlimit(:CORE)", :rlimit_core=>[n]]) {|io|
      assert_equal("[#{n}, #{n}]", io.read.chomp)
    }

    m, n = 0, max
    IO.popen([RUBY, "-e",
             "p Process.getrlimit(:CORE)", :rlimit_core=>[m,n]]) {|io|
      assert_equal("[#{m}, #{n}]", io.read.chomp)
    }

    m, n = 0, 0
    IO.popen([RUBY, "-e",
             "p Process.getrlimit(:CORE)", :rlimit_core=>[m,n]]) {|io|
      assert_equal("[#{m}, #{n}]", io.read.chomp)
    }

    n = max
    IO.popen([RUBY, "-e",
      "p Process.getrlimit(:CORE), Process.getrlimit(:CPU)",
      :rlimit_core=>n, :rlimit_cpu=>3600]) {|io|
      assert_equal("[#{n}, #{n}]\n[3600, 3600]", io.read.chomp)
    }
  end

  ENVCOMMAND = [RUBY, '-e', 'ENV.each {|k,v| puts "#{k}=#{v}" }']

  def test_execopts_env
    assert_raise(ArgumentError) {
      system({"F=O"=>"BAR"}, *TRUECOMMAND)
    }

    h = {}
    ENV.each {|k,v| h[k] = nil unless k.upcase == "PATH" }
    IO.popen([h, RUBY, '-e', 'puts ENV.keys.map{|e|e.upcase}']) {|io|
      assert_equal("PATH\n", io.read)
    }

    IO.popen([{"FOO"=>"BAR"}, *ENVCOMMAND]) {|io|
      assert_match(/^FOO=BAR$/, io.read)
    }

    with_tmpchdir {|d|
      system({"fofo"=>"haha"}, *ENVCOMMAND, STDOUT=>"out")
      assert_match(/^fofo=haha$/, File.read("out").chomp)
    }
  end

  def test_execopts_unsetenv_others
    IO.popen([*ENVCOMMAND, :unsetenv_others=>true]) {|io|
      assert_equal("", io.read)
    }
    IO.popen([{"A"=>"B"}, *ENVCOMMAND, :unsetenv_others=>true]) {|io|
      assert_equal("A=B\n", io.read)
    }
  end

  PWD = [RUBY, '-e', 'puts Dir.pwd']

  def test_execopts_chdir
    with_tmpchdir {|d|
      IO.popen([*PWD, :chdir => d]) {|io|
        assert_equal(d, io.read.chomp)
      }
      assert_raise(Errno::ENOENT) {
        Process.wait Process.spawn(*PWD, :chdir => "d/notexist")
      }
    }
  end

  UMASK = [RUBY, '-e', 'printf "%04o\n", File.umask']

  def test_execopts_umask
    IO.popen([*UMASK, :umask => 0]) {|io|
      assert_equal("0000", io.read.chomp)
    }
    IO.popen([*UMASK, :umask => 0777]) {|io|
      assert_equal("0777", io.read.chomp)
    }
  end

  def with_pipe
    begin
      r, w = IO.pipe
      yield r, w
    ensure
      r.close unless r.closed?
      w.close unless w.closed?
    end
  end

  def with_pipes(n)
    ary = []
    begin
      n.times {
        ary << IO.pipe
      }
      yield ary
    ensure
      ary.each {|r, w|
        r.close unless r.closed?
        w.close unless w.closed?
      }
    end
  end

  ECHO = lambda {|arg| [RUBY, '-e', "puts #{arg.dump}; STDOUT.flush"] }
  SORT = [RUBY, '-e', "puts ARGF.readlines.sort"]
  CAT = [RUBY, '-e', "IO.copy_stream STDIN, STDOUT"]

  def test_execopts_redirect
    with_tmpchdir {|d|
      Process.wait Process.spawn(*ECHO["a"], STDOUT=>["out", File::WRONLY|File::CREAT|File::TRUNC, 0644])
      assert_equal("a", File.read("out").chomp)
      Process.wait Process.spawn(*ECHO["0"], STDOUT=>["out", File::WRONLY|File::CREAT|File::APPEND, 0644])
      assert_equal("a\n0\n", File.read("out"))
      Process.wait Process.spawn(*SORT, STDIN=>["out", File::RDONLY, 0644],
                                         STDOUT=>["out2", File::WRONLY|File::CREAT|File::TRUNC, 0644])
      assert_equal("0\na\n", File.read("out2"))
      Process.wait Process.spawn(*ECHO["b"], [STDOUT, STDERR]=>["out", File::WRONLY|File::CREAT|File::TRUNC, 0644])
      assert_equal("b", File.read("out").chomp)
      # problem occur with valgrind
      #Process.wait Process.spawn(*ECHO["a"], STDOUT=>:close, STDERR=>["out", File::WRONLY|File::CREAT|File::TRUNC, 0644])
      #p File.read("out")
      #assert(!File.read("out").empty?) # error message such as "-e:1:in `flush': Bad file descriptor (Errno::EBADF)"
      Process.wait Process.spawn(*ECHO["c"], STDERR=>STDOUT, STDOUT=>["out", File::WRONLY|File::CREAT|File::TRUNC, 0644])
      assert_equal("c", File.read("out").chomp)
      File.open("out", "w") {|f|
        Process.wait Process.spawn(*ECHO["d"], f=>STDOUT, STDOUT=>f)
        assert_equal("d", File.read("out").chomp)
      }
      Process.wait Process.spawn(*ECHO["e"], STDOUT=>["out", File::WRONLY|File::CREAT|File::TRUNC, 0644],
                                 3=>STDOUT, 4=>STDOUT, 5=>STDOUT, 6=>STDOUT, 7=>STDOUT)
      assert_equal("e", File.read("out").chomp)
      File.open("out", "w") {|f|
        h = {STDOUT=>f, f=>STDOUT}
        3.upto(30) {|i| h[i] = STDOUT if f.fileno != i }
        Process.wait Process.spawn(*ECHO["f"], h)
        assert_equal("f", File.read("out").chomp)
      }
      assert_raise(ArgumentError) {
        Process.wait Process.spawn(*ECHO["f"], 1=>Process)
      }
      assert_raise(ArgumentError) {
        Process.wait Process.spawn(*ECHO["f"], [Process]=>1)
      }
      assert_raise(ArgumentError) {
        Process.wait Process.spawn(*ECHO["f"], [1, STDOUT]=>2)
      }
      assert_raise(ArgumentError) {
        Process.wait Process.spawn(*ECHO["f"], -1=>2)
      }
      Process.wait Process.spawn(*ECHO["hhh\nggg\n"], STDOUT=>"out")
      assert_equal("hhh\nggg\n", File.read("out"))
      Process.wait Process.spawn(*SORT, STDIN=>"out", STDOUT=>"out2")
      assert_equal("ggg\nhhh\n", File.read("out2"))

      assert_raise(Errno::ENOENT) {
        Process.wait Process.spawn("non-existing-command", (3..60).to_a=>["err", File::WRONLY|File::CREAT])
      }
      assert_equal("", File.read("err"))

      system(*ECHO["bb\naa\n"], STDOUT=>["out", "w"])
      assert_equal("bb\naa\n", File.read("out"))
      system(*SORT, STDIN=>["out"], STDOUT=>"out2")
      assert_equal("aa\nbb\n", File.read("out2"))

      with_pipe {|r1, w1|
        with_pipe {|r2, w2|
          pid = spawn(*SORT, STDIN=>r1, STDOUT=>w2, w1=>:close, r2=>:close)
          r1.close
          w2.close
          w1.puts "c"
          w1.puts "a"
          w1.puts "b"
          w1.close
          assert_equal("a\nb\nc\n", r2.read)
          Process.wait(pid)
        }
      }

      with_pipes(5) {|pipes|
        ios = pipes.flatten
        h = {}
        ios.length.times {|i| h[ios[i]] = ios[(i-1)%ios.length] }
        h2 = h.invert
        rios = pipes.map {|r, w| r }
        wios = pipes.map {|r, w| w }
        child_wfds = wios.map {|w| h2[w].fileno }
        pid = spawn(RUBY, "-e",
                "[#{child_wfds.join(',')}].each {|fd| IO.new(fd).puts fd }", h)
        pipes.each {|r, w|
          assert_equal("#{h2[w].fileno}\n", r.gets)
        }
        Process.wait pid;
      }

      with_pipes(5) {|pipes|
        ios = pipes.flatten
        h = {}
        ios.length.times {|i| h[ios[i]] = ios[(i+1)%ios.length] }
        h2 = h.invert
        rios = pipes.map {|r, w| r }
        wios = pipes.map {|r, w| w }
        child_wfds = wios.map {|w| h2[w].fileno }
        pid = spawn(RUBY, "-e",
                "[#{child_wfds.join(',')}].each {|fd| IO.new(fd).puts fd }", h)
        pipes.each {|r, w|
          assert_equal("#{h2[w].fileno}\n", r.gets)
        }
        Process.wait pid;
      }

      closed_fd = nil
      with_pipes(5) {|pipes|
        io = pipes.last.last
        closed_fd = io.fileno
      }
      assert_raise(Errno::EBADF) { Process.wait spawn(*TRUECOMMAND, closed_fd=>closed_fd) }

      with_pipe {|r, w|
        w.close_on_exec = true
        pid = spawn(RUBY, "-e", "IO.new(#{w.fileno}).print 'a'", w=>w)
        w.close
        assert_equal("a", r.read)
        Process.wait pid
      }

      system(*ECHO["funya"], :out=>"out")
      assert_equal("funya\n", File.read("out"))
      system(RUBY, '-e', 'STDOUT.reopen(STDERR); puts "henya"', :err=>"out")
      assert_equal("henya\n", File.read("out"))
      IO.popen([*CAT, :in=>"out"]) {|io|
        assert_equal("henya\n", io.read)
      }
    }
  end

  def test_execopts_exec
    with_tmpchdir {|d|
      write_file("s", 'exec "echo aaa", STDOUT=>"foo"')
      pid = spawn RUBY, 's'
      Process.wait pid
      assert_equal("aaa\n", File.read("foo"))
    }
  end

  def test_execopts_popen
    with_tmpchdir {|d|
      IO.popen("#{RUBY} -e 'puts :foo'") {|io| assert_equal("foo\n", io.read) }
      assert_raise(Errno::ENOENT) { IO.popen(["echo bar"]) {} } # assuming "echo bar" command not exist.
      IO.popen(ECHO["baz"]) {|io| assert_equal("baz\n", io.read) }
      assert_raise(ArgumentError) {
        IO.popen([*ECHO["qux"], STDOUT=>STDOUT]) {|io| }
      }
      IO.popen([*ECHO["hoge"], STDERR=>STDOUT]) {|io|
        assert_equal("hoge\n", io.read)
      }
      assert_raise(ArgumentError) {
        IO.popen([*ECHO["fuga"], STDOUT=>"out"]) {|io| }
      }
      with_pipe {|r, w|
        IO.popen([RUBY, '-e', 'IO.new(3).puts("a"); puts "b"', 3=>w]) {|io|
          assert_equal("b\n", io.read)
        }
        w.close
        assert_equal("a\n", r.read)
      }
      IO.popen([RUBY, '-e', "IO.new(9).puts(:b)",
               9=>["out2", File::WRONLY|File::CREAT|File::TRUNC]]) {|io|
        assert_equal("", io.read)
      }
      assert_equal("b\n", File.read("out2"))
    }
  end

  def test_popen_fork
    IO.popen("-") {|io|
      if !io
        puts "fooo"
      else
        assert_equal("fooo\n", io.read)
      end
    }
  end

  def test_fd_inheritance
    with_pipe {|r, w|
      system(RUBY, '-e', 'IO.new(ARGV[0].to_i).puts(:ba)', w.fileno.to_s)
      w.close
      assert_equal("ba\n", r.read)
    }
    with_pipe {|r, w|
      Process.wait spawn(RUBY, '-e',
                         'IO.new(ARGV[0].to_i).puts("bi") rescue nil',
                         w.fileno.to_s)
      w.close
      assert_equal("", r.read)
    }
    with_pipe {|r, w|
      with_tmpchdir {|d|
	write_file("s", <<-"End")
	  exec(#{RUBY.dump}, '-e',
	       'IO.new(ARGV[0].to_i).puts("bu") rescue nil',
	       #{w.fileno.to_s.dump})
	End
	Process.wait spawn(RUBY, "s", :close_others=>false)
	w.close
	assert_equal("bu\n", r.read)
      }
    }
    with_pipe {|r, w|
      io = IO.popen([RUBY, "-e", "STDERR.reopen(STDOUT); IO.new(#{w.fileno}).puts('me')"])
      w.close
      errmsg = io.read
      assert_equal("", r.read)
      assert_not_equal("", errmsg)
      Process.wait
    }
    with_pipe {|r, w|
      errmsg = `#{RUBY} -e "STDERR.reopen(STDOUT); IO.new(#{w.fileno}).puts(123)"`
      w.close
      assert_equal("", r.read)
      assert_not_equal("", errmsg)
    }
  end

  def test_execopts_close_others
    with_tmpchdir {|d|
      with_pipe {|r, w|
        system(RUBY, '-e', 'STDERR.reopen("err", "w"); IO.new(ARGV[0].to_i).puts("ma")', w.fileno.to_s, :close_others=>true)
        w.close
        assert_equal("", r.read)
        assert_not_equal("", File.read("err"))
        File.unlink("err")
      }
      with_pipe {|r, w|
        Process.wait spawn(RUBY, '-e', 'STDERR.reopen("err", "w"); IO.new(ARGV[0].to_i).puts("mi")', w.fileno.to_s, :close_others=>true)
        w.close
        assert_equal("", r.read)
        assert_not_equal("", File.read("err"))
        File.unlink("err")
      }
      with_pipe {|r, w|
        Process.wait spawn(RUBY, '-e', 'IO.new(ARGV[0].to_i).puts("bi")', w.fileno.to_s, :close_others=>false)
        w.close
        assert_equal("bi\n", r.read)
      }
      with_pipe {|r, w|
	write_file("s", <<-"End")
	  exec(#{RUBY.dump}, '-e',
	       'STDERR.reopen("err", "w"); IO.new(ARGV[0].to_i).puts("mu")',
	       #{w.fileno.to_s.dump},
	       :close_others=>true)
	End
        Process.wait spawn(RUBY, "s", :close_others=>false)
        w.close
        assert_equal("", r.read)
        assert_not_equal("", File.read("err"))
        File.unlink("err")
      }
      with_pipe {|r, w|
        io = IO.popen([RUBY, "-e", "STDERR.reopen(STDOUT); IO.new(#{w.fileno}).puts('me')", :close_others=>true])
        w.close
        errmsg = io.read
        assert_equal("", r.read)
        assert_not_equal("", errmsg)
        Process.wait
      }
      with_pipe {|r, w|
        io = IO.popen([RUBY, "-e", "STDERR.reopen(STDOUT); IO.new(#{w.fileno}).puts('mo')", :close_others=>false])
        w.close
        errmsg = io.read
        assert_equal("mo\n", r.read)
        assert_equal("", errmsg)
        Process.wait
      }
      with_pipe {|r, w|
        io = IO.popen([RUBY, "-e", "STDERR.reopen(STDOUT); IO.new(#{w.fileno}).puts('mo')", :close_others=>nil])
        w.close
        errmsg = io.read
        assert_equal("mo\n", r.read)
        assert_equal("", errmsg)
        Process.wait
      }

    }
  end

  def test_execopts_redirect_self
    with_pipe {|r, w|
      w << "haha\n"
      w.close
      r.close_on_exec = true
      IO.popen([RUBY, "-e", "print IO.new(#{r.fileno}).read", r.fileno=>r.fileno, :close_others=>false]) {|io|
        assert_equal("haha\n", io.read)
      }
    }
  end

  def test_execopts_duplex_io
    IO.popen("#{RUBY} -e ''", "r+") {|duplex|
      assert_raise(ArgumentError) { system("#{RUBY} -e ''", duplex=>STDOUT) }
      assert_raise(ArgumentError) { system("#{RUBY} -e ''", STDOUT=>duplex) }
    }
  end

  def test_execopts_modification
    h = {}
    Process.wait spawn(*TRUECOMMAND, h)
    assert_equal({}, h)

    h = {}
    system(*TRUECOMMAND, h)
    assert_equal({}, h)

    h = {}
    io = IO.popen([*TRUECOMMAND, h])
    io.close
    assert_equal({}, h)
  end

  def test_system_noshell
    str = "echo non existing command name which contains spaces"
    assert_nil(system([str, str]))
  end

  def test_spawn_noshell
    str = "echo non existing command name which contains spaces"
    assert_raise(Errno::ENOENT) { spawn([str, str]) }
  end

  def test_popen_noshell
    str = "echo non existing command name which contains spaces"
    assert_raise(Errno::ENOENT) { IO.popen([str, str]) }
  end

  def test_exec_noshell
    with_tmpchdir {|d|
      with_pipe {|r, w|
	write_file("s", <<-"End")
	  str = "echo non existing command name which contains spaces"
	  w = IO.new(#{w.fileno})
	  STDOUT.reopen(w)
	  STDERR.reopen(w)
	  begin
	    exec [str, str]
	  rescue Errno::ENOENT
	    w.write "Errno::ENOENT success"
	  end
	End
	system(RUBY, "s", :close_others=>false)
	w.close
	assert_equal("Errno::ENOENT success", r.read)
      }
    }
  end

  def test_system_wordsplit
    with_tmpchdir {|d|
      write_file("script", <<-'End')
        File.open("result", "w") {|t| t << "haha pid=#{$$} ppid=#{Process.ppid}" }
        exit 5
      End
      str = "#{RUBY} script"
      ret = system(str)
      status = $?
      assert_equal(false, ret)
      assert(status.exited?)
      assert_equal(5, status.exitstatus)
      assert_equal("haha pid=#{status.pid} ppid=#{$$}", File.read("result"))
    }
  end

  def test_spawn_wordsplit
    with_tmpchdir {|d|
      write_file("script", <<-'End')
        File.open("result", "w") {|t| t << "hihi pid=#{$$} ppid=#{Process.ppid}" }
        exit 6
      End
      str = "#{RUBY} script"
      pid = spawn(str)
      Process.wait pid
      status = $?
      assert_equal(pid, status.pid)
      assert(status.exited?)
      assert_equal(6, status.exitstatus)
      assert_equal("hihi pid=#{status.pid} ppid=#{$$}", File.read("result"))
    }
  end

  def test_popen_wordsplit
    with_tmpchdir {|d|
      write_file("script", <<-'End')
        print "fufu pid=#{$$} ppid=#{Process.ppid}"
        exit 7
      End
      str = "#{RUBY} script"
      io = IO.popen(str)
      pid = io.pid
      result = io.read
      io.close
      status = $?
      assert_equal(pid, status.pid)
      assert(status.exited?)
      assert_equal(7, status.exitstatus)
      assert_equal("fufu pid=#{status.pid} ppid=#{$$}", result)
    }
  end

  def test_exec_wordsplit
    with_tmpchdir {|d|
      write_file("script", <<-'End')
        File.open("result", "w") {|t| t << "hehe pid=#{$$} ppid=#{Process.ppid}" }
        exit 6
      End
      write_file("s", <<-"End")
	ruby = #{RUBY.dump}
	exec "\#{ruby} script"
      End
      pid = spawn(RUBY, "s")
      Process.wait pid
      status = $?
      assert_equal(pid, status.pid)
      assert(status.exited?)
      assert_equal(6, status.exitstatus)
      assert_equal("hehe pid=#{status.pid} ppid=#{$$}", File.read("result"))
    }
  end

  def test_system_shell
    with_tmpchdir {|d|
      write_file("script1", <<-'End')
        File.open("result1", "w") {|t| t << "taka pid=#{$$} ppid=#{Process.ppid}" }
        exit 7
      End
      write_file("script2", <<-'End')
        File.open("result2", "w") {|t| t << "taki pid=#{$$} ppid=#{Process.ppid}" }
        exit 8
      End
      ret = system("#{RUBY} script1 || #{RUBY} script2")
      status = $?
      assert_equal(false, ret)
      assert(status.exited?)
      result1 = File.read("result1")
      result2 = File.read("result2")
      assert_match(/\Ataka pid=\d+ ppid=\d+\z/, result1)
      assert_match(/\Ataki pid=\d+ ppid=\d+\z/, result2)
      assert_not_equal(result1[/\d+/].to_i, status.pid)
    }
  end

  def test_spawn_shell
    with_tmpchdir {|d|
      write_file("script1", <<-'End')
        File.open("result1", "w") {|t| t << "taku pid=#{$$} ppid=#{Process.ppid}" }
        exit 7
      End
      write_file("script2", <<-'End')
        File.open("result2", "w") {|t| t << "take pid=#{$$} ppid=#{Process.ppid}" }
        exit 8
      End
      pid = spawn("#{RUBY} script1 || #{RUBY} script2")
      Process.wait pid
      status = $?
      assert(status.exited?)
      assert(!status.success?)
      result1 = File.read("result1")
      result2 = File.read("result2")
      assert_match(/\Ataku pid=\d+ ppid=\d+\z/, result1)
      assert_match(/\Atake pid=\d+ ppid=\d+\z/, result2)
      assert_not_equal(result1[/\d+/].to_i, status.pid)
    }
  end

  def test_popen_shell
    with_tmpchdir {|d|
      write_file("script1", <<-'End')
        puts "tako pid=#{$$} ppid=#{Process.ppid}"
        exit 7
      End
      write_file("script2", <<-'End')
        puts "tika pid=#{$$} ppid=#{Process.ppid}"
        exit 8
      End
      io = IO.popen("#{RUBY} script1 || #{RUBY} script2")
      result = io.read
      io.close
      status = $?
      assert(status.exited?)
      assert(!status.success?)
      assert_match(/\Atako pid=\d+ ppid=\d+\ntika pid=\d+ ppid=\d+\n\z/, result)
      assert_not_equal(result[/\d+/].to_i, status.pid)
    }
  end

  def test_exec_shell
    with_tmpchdir {|d|
      write_file("script1", <<-'End')
        File.open("result1", "w") {|t| t << "tiki pid=#{$$} ppid=#{Process.ppid}" }
        exit 7
      End
      write_file("script2", <<-'End')
        File.open("result2", "w") {|t| t << "tiku pid=#{$$} ppid=#{Process.ppid}" }
        exit 8
      End
      write_file("s", <<-"End")
	ruby = #{RUBY.dump}
	exec("\#{ruby} script1 || \#{ruby} script2")
      End
      pid = spawn RUBY, "s"
      Process.wait pid
      status = $?
      assert(status.exited?)
      assert(!status.success?)
      result1 = File.read("result1")
      result2 = File.read("result2")
      assert_match(/\Atiki pid=\d+ ppid=\d+\z/, result1)
      assert_match(/\Atiku pid=\d+ ppid=\d+\z/, result2)
      assert_not_equal(result1[/\d+/].to_i, status.pid)
    }
  end

  def test_argv0
    with_tmpchdir {|d|
      assert_equal(false, system([RUBY, "asdfg"], "-e", "exit false"))
      assert_equal(true, system([RUBY, "zxcvb"], "-e", "exit true"))

      Process.wait spawn([RUBY, "poiu"], "-e", "exit 4")
      assert_equal(4, $?.exitstatus)

      assert_equal("1", IO.popen([[RUBY, "qwerty"], "-e", "print 1"]).read)
      Process.wait

      write_file("s", <<-"End")
        exec([#{RUBY.dump}, "lkjh"], "-e", "exit 5")
      End
      pid = spawn RUBY, "s"
      Process.wait pid
      assert_equal(5, $?.exitstatus)
    }
  end

  def with_stdin(filename)
    open(filename) {|f|
      begin
        old = STDIN.dup
        begin
          STDIN.reopen(filename)
          yield
        ensure
          STDIN.reopen(old)
        end
      ensure
        old.close
      end
    }
  end

  def test_argv0_noarg
    with_tmpchdir {|d|
      open("t", "w") {|f| f.print "exit true" }
      open("f", "w") {|f| f.print "exit false" }

      with_stdin("t") { assert_equal(true, system([RUBY, "qaz"])) }
      with_stdin("f") { assert_equal(false, system([RUBY, "wsx"])) }

      with_stdin("t") { Process.wait spawn([RUBY, "edc"]) }
      assert($?.success?)
      with_stdin("f") { Process.wait spawn([RUBY, "rfv"]) }
      assert(!$?.success?)

      with_stdin("t") { IO.popen([[RUBY, "tgb"]]) {|io| assert_equal("", io.read) } }
      assert($?.success?)
      with_stdin("f") { IO.popen([[RUBY, "yhn"]]) {|io| assert_equal("", io.read) } }
      assert(!$?.success?)

      status = run_in_child "STDIN.reopen('t'); exec([#{RUBY.dump}, 'ujm'])"
      assert(status.success?)
      status = run_in_child "STDIN.reopen('f'); exec([#{RUBY.dump}, 'ik,'])"
      assert(!status.success?)
    }
  end

  def test_status
    with_tmpchdir do
      s = run_in_child("exit 1")
      assert_equal("#<Process::Status: pid #{ s.pid } exit #{ s.exitstatus }>", s.inspect)

      assert_equal(s, s)
      assert_equal(s, s.to_i)

      assert_equal(s.to_i & 0x55555555, s & 0x55555555)
      assert_equal(s.to_i >> 1, s >> 1)
      assert_equal(false, s.stopped?)
      assert_equal(nil, s.stopsig)
    end
  end

  def test_status_kill
    return unless Process.respond_to?(:kill)
    return unless Signal.list.include?("QUIT")

    with_tmpchdir do
      write_file("foo", "sleep 30")
      pid = spawn(RUBY, "foo")
      Thread.new { sleep 1; Process.kill(:SIGQUIT, pid) }
      Process.wait(pid)
      s = $?
      assert_equal("#<Process::Status: pid #{ s.pid } SIGQUIT (signal #{ s.termsig })>", s.inspect)
      assert_equal(false, s.exited?)
      assert_equal(nil, s.success?)
    end
  end

  def test_wait_without_arg
    with_tmpchdir do
      write_file("foo", "sleep 0.1")
      pid = spawn(RUBY, "foo")
      assert_equal(pid, Process.wait)
    end
  end

  def test_wait2
    with_tmpchdir do
      write_file("foo", "sleep 0.1")
      pid = spawn(RUBY, "foo")
      assert_equal([pid, 0], Process.wait2)
    end
  end

  def test_waitall
    with_tmpchdir do
      write_file("foo", "sleep 0.1")
      ps = (0...3).map { spawn(RUBY, "foo") }.sort
      ss = Process.waitall.sort
      ps.zip(ss) do |p1, (p2, s)|
        assert_equal(p1, p2)
        assert_equal(p1, s.pid)
      end
    end
  end

  def test_abort
    with_tmpchdir do
      s = run_in_child("abort")
      assert_not_equal(0, s.exitstatus)
    end
  end

  def test_sleep
    assert_raise(ArgumentError) { sleep(1, 1) }
  end

  def test_getpgid
    assert_kind_of(Integer, Process.getpgid(Process.ppid))
  rescue NotImplementedError
  end

  def test_getpriority
    assert_kind_of(Integer, Process.getpriority(Process::PRIO_USER, 0))
  rescue NotImplementedError
  end

  def test_setpriority
    assert_nothing_raised do
      pr = Process.getpriority(Process::PRIO_USER, 0)
      Process.setpriority(Process::PRIO_USER, 0, pr)
    end
  rescue NotImplementedError
  end

  def test_getuid
    assert_kind_of(Integer, Process.uid)
  end

  def test_groups
    gs = Process.groups
    assert_instance_of(Array, gs)
    gs.each {|g| assert_kind_of(Integer, g) }
  rescue NotImplementedError
  end

  def test_maxgroups
    assert_kind_of(Integer, Process.maxgroups)
  end

  def test_geteuid
    assert_kind_of(Integer, Process.egid)
  end

  def test_uid_re_exchangeable_p
    r = Process::UID.re_exchangeable?
    assert(true == r || false == r)
  end

  def test_gid_re_exchangeable_p
    r = Process::GID.re_exchangeable?
    assert(true == r || false == r)
  end

  def test_uid_sid_available?
    r = Process::UID.sid_available?
    assert(true == r || false == r)
  end

  def test_gid_sid_available?
    r = Process::GID.sid_available?
    assert(true == r || false == r)
  end

end
