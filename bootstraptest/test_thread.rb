# Thread and Fiber

assert_equal %q{ok}, %q{
  Thread.new{
  }.join
  :ok
}
assert_equal %q{ok}, %q{
  Thread.new{
    :ok
  }.value
}
assert_equal %q{20100}, %q{
  v = 0
  (1..200).map{|i|
    Thread.new{
      i
    }
  }.each{|t|
    v += t.value
  }
  v
}
assert_equal %q{5000}, %q{
  5000.times{|e|
    (1..2).map{
      Thread.new{
      }
    }.each{|e|
      e.join()
    }
  }
}
assert_equal %q{5000}, %q{
  5000.times{|e|
    (1..2).map{
      Thread.new{
      }
    }.each{|e|
      e.join(1000000000)
    }
  }
}
assert_equal %q{5000}, %q{
  5000.times{
    t = Thread.new{}
    while t.alive?
      Thread.pass
    end
  }
}
assert_equal %q{100}, %q{
  100.times{
    Thread.new{loop{Thread.pass}}
  }
}
assert_equal %q{ok}, %q{
  Thread.new{
    :ok
  }.join.value
}
assert_equal %q{ok}, %q{
  begin
    Thread.new{
      raise "ok"
    }.join
  rescue => e
    e
  end
}
assert_equal %q{ok}, %q{
  ans = nil
  t = Thread.new{
    begin
      sleep 0.5
    ensure
      ans = :ok
    end
  }
  Thread.pass
  t.kill
  t.join
  ans
}
assert_equal %q{ok}, %q{
  t = Thread.new{
    sleep
  }
  sleep 0.1
  t.raise
  begin
    t.join
    :ng
  rescue
    :ok
  end
}
assert_equal %q{ok}, %q{
  t = Thread.new{
    loop{}
  }
  Thread.pass
  t.raise
  begin
    t.join
    :ng
  rescue
    :ok
  end
}
assert_equal %q{ok}, %q{
  t = Thread.new{
  }
  Thread.pass
  t.join
  t.raise # raise to exited thread
  begin
    t.join
    :ok
  rescue
    :ng
  end
}
assert_equal %q{run}, %q{
  t = Thread.new{
    loop{}
  }
  st = t.status
  t.kill
  st
}
assert_equal %q{sleep}, %q{
  t = Thread.new{
    sleep
  }
  sleep 0.1
  st = t.status
  t.kill
  st
}
assert_equal %q{false}, %q{
  t = Thread.new{
  }
  t.kill
  sleep 0.1
  t.status
}
assert_equal %q{[ThreadGroup, true]}, %q{
  ptg = Thread.current.group
  Thread.new{
    ctg = Thread.current.group
    [ctg.class, ctg == ptg]
  }.value
}
assert_equal %q{[1, 1]}, %q{
  thg = ThreadGroup.new

  t = Thread.new{
    thg.add Thread.current
    sleep
  }
  sleep 0.1
  [thg.list.size, ThreadGroup::Default.list.size]
}
assert_equal %q{true}, %q{
  thg = ThreadGroup.new

  t = Thread.new{sleep 5}
  thg.add t
  thg.list.include?(t)
}
assert_equal %q{[true, nil, true]}, %q{
  /a/ =~ 'a'
  $a = $~
  Thread.new{
    $b = $~
    /a/ =~ 'a'
    $c = $~
  }
  $d = $~
  [$a == $d, $b, $c != $d]
}
assert_equal %q{11}, %q{
  Thread.current[:a] = 1
  Thread.new{
    Thread.current[:a] = 10
    Thread.pass
    Thread.current[:a]
  }.value + Thread.current[:a]
}
assert_equal %q{100}, %q{
begin
  100.times do |i|
    begin
      Thread.start(Thread.current) {|u| u.raise }
      raise
    rescue
    ensure
    end
  end
rescue
  100
end
}, '[ruby-dev:31371]'

assert_equal 'true', %{
  t = Thread.new { loop {} }
  begin
    pid = fork {
      exit t.status != "run"
    }
    Process.wait pid
    $?.success?
  rescue NotImplementedError
    true
  end
}

assert_finish 3, %{
  th = Thread.new {sleep 2}
  th.join(1)
  th.join
}

assert_finish 3, %{
  require 'timeout'
  th = Thread.new {sleep 2}
  begin
    Timeout.timeout(1) {th.join}
  rescue Timeout::Error
  end
  th.join
}

assert_normal_exit %q{
  STDERR.reopen(STDOUT)
  exec "/"
}

assert_normal_exit %q{
  (0..10).map {
    Thread.new {
     10000.times {
        Object.new.to_s
      }
    }
  }.each {|t|
    t.join
  }
}

assert_equal 'ok', %q{
  def m
    t = Thread.new { while true do // =~ "" end }
    sleep 0.1
    10.times {
      if /((ab)*(ab)*)*(b)/ =~ "ab"*7
        return :ng if !$4
        return :ng if $~.size != 5
      end
    }
    :ok
  ensure
    Thread.kill t
  end
  m
}, '[ruby-dev:34492]'

assert_normal_exit %q{
  at_exit { Fiber.new{}.resume }
}

assert_normal_exit %q{
  g = enum_for(:local_variables)
  loop { g.next }
}, '[ruby-dev:34128]'

assert_normal_exit %q{
  g = enum_for(:block_given?)
  loop { g.next }
}, '[ruby-dev:34128]'

assert_normal_exit %q{
  g = enum_for(:binding)
  loop { g.next }
}, '[ruby-dev:34128]'

assert_normal_exit %q{
  g = "abc".enum_for(:scan, /./)
  loop { g.next }
}, '[ruby-dev:34128]'

assert_normal_exit %q{
  g = Module.enum_for(:new)
  loop { g.next }
}, '[ruby-dev:34128]'

assert_normal_exit %q{
  Fiber.new(&Object.method(:class_eval)).resume("foo")
}, '[ruby-dev:34128]'

assert_normal_exit %q{
  Thread.new("foo", &Object.method(:class_eval)).join
}, '[ruby-dev:34128]'
