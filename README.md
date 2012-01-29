rack-session-sequel
====================

Rack session store for Sequel

<http://github.com/migrs/rack-session-sequel>

[![Build Status](https://secure.travis-ci.org/migrs/rack-session-sequel.png)](http://travis-ci.org/migrs/rack-session-sequel)

## Installation

    gem install rack-session-sequel

## Usage

Simple (In-Memory Sequel Database)

    use Rack::Session::Sequel

Specify DB URI (see [Connecting to a database](http://sequel.rubyforge.org/rdoc/files/doc/opening_databases_rdoc.html))

    use Rack::Session::Sequel, 'sqlite://blog.db'

Set Sequel DB instance

    DB = Sequel.connect('sqlite://blog.db')
    use Rack::Session::Sequel, DB

With some config

    use Rack::Session::Sequel, :db => DB, :expire_after => 600
    use Rack::Session::Sequel, :db_uri => 'sqlite://blog.db', :expire_after => 600

Specify session table name

    use Rack::Session::Sequel, :db => DB, :table_name => :tbl_session

## About Sequel

- <http://sequel.rubyforge.org/>

## License
[rack-session-sequel](http://github.com/migrs/rack-session-sequel) is Copyright (c) 2012 [Masato Igarashi](http://github.com/migrs)(@[migrs](http://twitter.com/migrs)) and distributed under the [MIT license](http://www.opensource.org/licenses/mit-license).
