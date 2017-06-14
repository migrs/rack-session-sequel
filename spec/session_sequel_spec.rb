require 'thread'
require 'rack/mock'
require 'rack/session/sequel'
require 'fileutils'

describe Rack::Session::Sequel do
  session_key = Rack::Session::Sequel::DEFAULT_OPTIONS[:key]
  session_match = /#{session_key}=[0-9a-fA-F]+;/

  incrementor = lambda do |env|
    env["rack.session"]["counter"] ||= 0
    env["rack.session"]["counter"] += 1
    Rack::Response.new(env["rack.session"].inspect).to_a
  end

  session_id = lambda do |env|
    Rack::Response.new(env["rack.session"].inspect).to_a
  end

  nothing = lambda do |env|
    Rack::Response.new("Nothing").to_a
  end

  drop_session = lambda do |env|
    env['rack.session.options'][:drop] = true
    incrementor.call(env)
  end

  renew_session = lambda do |env|
    env['rack.session.options'][:renew] = true
    incrementor.call(env)
  end

  defer_session = lambda do |env|
    env['rack.session.options'][:defer] = true
    incrementor.call(env)
  end

  it "creates a new cookie" do
    pool = Rack::Session::Sequel.new(incrementor)
    res = Rack::MockRequest.new(pool).get("/")
    expect(res["Set-Cookie"]).to match session_match
    expect(res.body).to eq '{"counter"=>1}'
  end

  it "determines session from a cookie" do
    pool = Rack::Session::Sequel.new(incrementor)
    req = Rack::MockRequest.new(pool)
    cookie = req.get("/")["Set-Cookie"]
    expect(req.get("/", "HTTP_COOKIE" => cookie).body).to eq '{"counter"=>2}'
    expect(req.get("/", "HTTP_COOKIE" => cookie).body).to eq '{"counter"=>3}'
  end

  it "survives nonexistant cookies" do
    pool = Rack::Session::Sequel.new(incrementor)
    res = Rack::MockRequest.new(pool).
      get("/", "HTTP_COOKIE" => "#{session_key}=blarghfasel")
    expect(res.body).to eq '{"counter"=>1}'
  end

  it "does not send the same session id if it did not change" do
    pool = Rack::Session::Sequel.new(incrementor)
    req = Rack::MockRequest.new(pool)

    res0 = req.get("/")
    cookie = res0["Set-Cookie"][session_match]
    expect(res0.body).to eq '{"counter"=>1}'
    expect(pool.pool.count).to eq 1

    res1 = req.get("/", "HTTP_COOKIE" => cookie)
    expect(res1["Set-Cookie"]).to be_nil
    expect(res1.body).to eq '{"counter"=>2}'
    expect(pool.pool.count).to eq 1

    res2 = req.get("/", "HTTP_COOKIE" => cookie)
    expect(res2["Set-Cookie"]).to be_nil
    expect(res2.body).to eq '{"counter"=>3}'
    expect(pool.pool.count).to eq 1
  end

  it "deletes cookies with :drop option" do
    pool = Rack::Session::Sequel.new(incrementor)
    req = Rack::MockRequest.new(pool)
    drop = Rack::Utils::Context.new(pool, drop_session)
    dreq = Rack::MockRequest.new(drop)

    res1 = req.get("/")
    session = (cookie = res1["Set-Cookie"])[session_match]
    expect(res1.body).to eq '{"counter"=>1}'
    expect(pool.pool.count).to eq 1

    res2 = dreq.get("/", "HTTP_COOKIE" => cookie)
    expect(res2["Set-Cookie"]).to be_nil
    expect(res2.body).to eq '{"counter"=>2}'
    expect(pool.pool.count).to eq 0

    res3 = req.get("/", "HTTP_COOKIE" => cookie)
    expect(res3["Set-Cookie"][session_match]).to_not eq session
    expect(res3.body).to eq '{"counter"=>1}'
    expect(pool.pool.count).to eq 1
  end

  it "provides new session id with :renew option" do
    pool = Rack::Session::Sequel.new(incrementor)
    req = Rack::MockRequest.new(pool)
    renew = Rack::Utils::Context.new(pool, renew_session)
    rreq = Rack::MockRequest.new(renew)

    res1 = req.get("/")
    session = (cookie = res1["Set-Cookie"])[session_match]
    expect(res1.body).to eq '{"counter"=>1}'
    expect(pool.pool.count).to eq 1

    res2 = rreq.get("/", "HTTP_COOKIE" => cookie)
    new_cookie = res2["Set-Cookie"]
    new_session = new_cookie[session_match]
    expect(new_session).to_not eq session
    expect(res2.body).to eq '{"counter"=>2}'
    expect(pool.pool.count).to eq 1

    res3 = req.get("/", "HTTP_COOKIE" => new_cookie)
    expect(res3.body).to eq '{"counter"=>3}'
    expect(pool.pool.count).to eq 1

    res4 = req.get("/", "HTTP_COOKIE" => cookie)
    expect(res4.body).to eq '{"counter"=>1}'
    expect(pool.pool.count).to eq 2
  end

  it "omits cookie with :defer option" do
    pool = Rack::Session::Sequel.new(incrementor)
    defer = Rack::Utils::Context.new(pool, defer_session)
    dreq = Rack::MockRequest.new(defer)

    res1 = dreq.get("/")
    expect(res1["Set-Cookie"]).to eq nil
    expect(res1.body).to eq '{"counter"=>1}'
    expect(pool.pool.count).to eq 1
  end

  # anyone know how to do this better?
  it "should merge sessions when multithreaded" do
    unless $DEBUG
      expect(1).to eq 1
      next
    end

    warn 'Running multithread tests for Session::Sequel'
    pool = Rack::Session::Sequel.new(incrementor)
    req = Rack::MockRequest.new(pool)

    res = req.get('/')
    expect(res.body).to eq '{"counter"=>1}'
    cookie = res["Set-Cookie"]
    sess_id = cookie[/#{pool.key}=([^,;]+)/,1]

    delta_incrementor = lambda do |env|
      # emulate disconjoinment of threading
      env['rack.session'] = env['rack.session'].dup
      Thread.stop
      env['rack.session'][(Time.now.usec*rand).to_i] = true
      incrementor.call(env)
    end
    tses = Rack::Utils::Context.new pool, delta_incrementor
    treq = Rack::MockRequest.new(tses)
    tnum = rand(7).to_i+5
    r = Array.new(tnum) do
      Thread.new(treq) do |run|
        run.get('/', "HTTP_COOKIE" => cookie, 'rack.multithread' => true)
      end
    end.reverse.map{|t| t.run.join.value }
    r.each do |resp|
      expect(resp['Set-Cookie']).to eq cookie
      expect(resp.body).to include '"counter"=>2'
    end

    session = pool.pool[sess_id]
    expect(session.count).to eq tnum+1 # counter
    expect(session['counter']).to eq 2 # meeeh
  end

  it "does not return a cookie if cookie was not read/written" do
    app = Rack::Session::Sequel.new(nothing)
    res = Rack::MockRequest.new(app).get("/")
    expect(res["Set-Cookie"]).to be_nil
  end

  it "does not return a cookie if cookie was not written (only read)" do
    app = Rack::Session::Sequel.new(session_id)
    res = Rack::MockRequest.new(app).get("/")
    expect(res["Set-Cookie"]).to be_nil
  end

  it "returns even if not read/written if :expire_after is set" do
    app = Rack::Session::Sequel.new(nothing, :expire_after => 3600)
    res = Rack::MockRequest.new(app).get("/", 'rack.session' => {'not' => 'empty'})
    expect(res["Set-Cookie"]).to_not be_nil
  end

  it "returns no cookie if no data was written and no session was created previously, even if :expire_after is set" do
    app = Rack::Session::Sequel.new(nothing, :expire_after => 3600)
    res = Rack::MockRequest.new(app).get("/")
    expect(res["Set-Cookie"]).to be_nil
  end
end
