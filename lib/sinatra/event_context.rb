class Sinatra::EventContext
  
  attr_reader :request, :response, :route_params
  
  def logger
    Sinatra.logger
  end
  
  def initialize(request, response, route_params)
    @request, @response, @route_params = 
      request, response, route_params
  end
  
  def params
    @params ||= request.params.merge(route_params).symbolize_keys
  end
  
  def complete(b)
    self.instance_eval(&b)
  end
  
  # redirect to another url It can be like /foo/bar
  # for redirecting within your same app. Or it can
  # be a fully qualified url to another site.
  def redirect(url)
    logger.info "Redirecting to: #{url}"
    status(302)
    headers.merge!('Location' => url)
    return ''
  end
  
  def method_missing(name, *args)
    if args.size == 1 && response.respond_to?("#{name}=")
      response.send("#{name}=", args.first)
    else
      response.send(name, *args)
    end
  end
  
end
