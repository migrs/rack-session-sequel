require 'rack/session/abstract/id'
require 'sequel'

module Rack
  module Session
    class Sequel < Abstract::ID

      attr_reader :mutex, :pool

      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge \
        :table_name => :sessions, :db_uri => 'sqlite:/'

      def initialize(app, options={})
        options = {:db => options } if options.kind_of? ::Sequel::Database
        options = {:db_uri => options } if options.is_a? String
        super
        @pool = setup_database[@default_options[:table_name]]
        @mutex = Mutex.new
      end

      def generate_sid
        loop do
          sid = super
          break sid unless _exists? sid
        end
      end

      def get_session(env, sid)
        with_lock(env, [nil, {}]) do
          unless sid and session = _get(sid)
            sid, session = generate_sid, {}
            _put sid, session
          end
          [sid, session]
        end
      end

      def set_session(env, session_id, new_session, options)
        with_lock(env, false) do
          _put session_id, new_session
          session_id
        end
      end

      def destroy_session(env, session_id, options)
        with_lock(env) do
          _delete(session_id)
          generate_sid unless options[:drop]
        end
      end

      def with_lock(env, default=nil)
        @mutex.lock if env['rack.multithread']
        yield
      rescue
        default
      ensure
        @mutex.unlock if @mutex.locked?
      end

    private
      def setup_database
        (@default_options[:db] || ::Sequel.connect(@default_options[:db_uri])).tap do |db|
          db.create_table @default_options[:table_name] do
            #primary_key :id
            String :sid, :unique => true,  :null => false, :primary_key => true
            text :session, :null => false
            DateTime :created_at, :null => false
            DateTime :updated_at
          end unless db.table_exists?(@default_options[:table_name])
        end
      end

      def _put(sid, session)
        if _exists?(sid)
          _record(sid).update :session  => [Marshal.dump(session)].pack('m*'), :updated_at => Time.now.utc
        else
          @pool.insert :sid => sid, :session => [Marshal.dump(session)].pack('m*'), :created_at => Time.now.utc
        end
      end

      def _get(sid)
        if _exists?(sid)
          Marshal.load(_record(sid).first[:session].unpack('m*').first)
        end
      end

      def _delete(sid)
        if _exists?(sid)
          _record(sid).delete
        end
      end

      def _exists?(sid)
        !_record(sid).empty?
      end

      def _record(sid)
        @pool.filter('sid = ?', sid)
      end
    end
  end
end

