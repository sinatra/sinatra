module Sinatra

  def default_send_file_options 
    @default_send_file_options ||= {
      :type         => 'application/octet-stream'.freeze,
      :disposition  => 'attachment'.freeze
    }.freeze
  end  

  # Adapted from Merb greatness
  module SendFileMixin

    # redirect to another url It can be like /foo/bar
    # for redirecting within your same app. Or it can
    # be a fully qualified url to another site.
    def redirect(url)
      # MERB_LOGGER.info("Redirecting to: #{url}")
      status(302)
      headers.merge!({'Location'=> url})
      return ''
    end
    
    # pass in a path to a file and this will set the
    # right headers and let mongrel do its thang and
    # serve the static file directly.
    def send_file(file, opts={})
      opts.update(Sinatra.default_send_file_options.merge(opts))
      disposition = opts[:disposition].dup || 'attachment'
      disposition << %(; filename="#{opts[:filename] ? opts[:filename] : File.basename(file)}")
      headers.update(
        'Content-Type'              => opts[:type].strip,  # fixes a problem with extra '\r' with some browsers
        'Content-Disposition'       => disposition,
        'Content-Transfer-Encoding' => 'binary',
        'X-SENDFILE'                => file
      )
      return
    end
    
    # stream_file( { :filename => file_name, 
    #                :type => content_type,
    #                :content_length => content_length }) do
    #   AWS::S3::S3Object.stream(user.folder_name + "-" + user_file.unique_id, bucket_name) do |chunk|
    #       response.write chunk
    #   end
    # end
    def stream_file(opts={}, &stream)
      opts.update(Merb::Const::DEFAULT_SEND_FILE_OPTIONS.merge(opts))
      disposition = opts[:disposition].dup || 'attachment'
      disposition << %(; filename="#{opts[:filename]}")
      response.headers.update(
        'Content-Type'              => opts[:type].strip,  # fixes a problem with extra '\r' with some browsers
        'Content-Disposition'       => disposition,
        'Content-Transfer-Encoding' => 'binary',
        'CONTENT-LENGTH'            => opts[:content_length]
      )
      response.send_status(opts[:content_length])
      response.send_header
      stream
    end
    

    # This uses nginx X-Accel-Redirect header to send
    # a file directly from nginx. See the nginx wiki:
    # http://wiki.codemongers.com/NginxXSendfile
    def nginx_send_file(file)
      headers['X-Accel-Redirect'] = File.expand_path(file)
      return
    end  

  end
  
end