require 'sinatra/base'

module Sinatra

  # = Sinatra::WebDAV
  #
  # This extensions provides WebDAV verbs, as defined by RFC 4918
  # (https://tools.ietf.org/html/rfc4918). To use this in your app,
  # just +register+ it:
  #
  #   require 'sinatra/base'
  #   require 'sinatra/webdav'
  #
  #   class Application < Sinatra::Base
  #     register Sinatra::WebDAV
  #
  #     # Now you can use any WebDAV verb:
  #     propfind '/2014/january/21' do
  #       'I have a lunch at 9 PM'
  #     end
  #   end
  #
  # You can use it in classic application just by requring the extension:
  #
  #   require 'sinatra'
  #   require 'sinatra/webdav'
  #
  #   mkcol '/2015' do
  #     'You started 2015!'
  #   end
  #
  module WebDAV
    def self.registered(_)
      Sinatra::Request.include WebDAV::Request
    end

    module Request
      def self.included(base)
        base.class_eval do
          alias _safe? safe?
          alias _idempotent? idempotent?

          def safe?
            _safe? or propfind?
          end

          def idempotent?
            _idempotent? or propfind? or move? or unlock? # or lock?
          end
        end
      end

      def propfind?
        request_method == 'PROPFIND'
      end

      def proppatch?
        request_method == 'PROPPATCH'
      end

      def mkcol?
        request_method == 'MKCOL'
      end

      def copy?
        request_method == 'COPY'
      end

      def move?
        request_method == 'MOVE'
      end

      #def lock?
      #  request_method == 'LOCK'
      #end

      def unlock?
        request_method == 'UNLOCK'
      end
    end

    def propfind(path, opts = {}, &bk)  route 'PROPFIND',  path, opts, &bk end
    def proppatch(path, opts = {}, &bk) route 'PROPPATCH', path, opts, &bk end
    def mkcol(path, opts = {}, &bk)     route 'MKCOL',     path, opts, &bk end
    def copy(path, opts = {}, &bk)      route 'COPY',      path, opts, &bk end
    def move(path, opts = {}, &bk)      route 'MOVE',      path, opts, &bk end
    #def lock(path, opts = {}, &bk)      route 'LOCK',      path, opts, &bk end
    def unlock(path, opts = {}, &bk)    route 'UNLOCK',    path, opts, &bk end
  end

  register WebDAV
  Delegator.delegate :propfind, :proppatch, :mkcol, :copy, :move, :unlock # :lock
end
