warn "Sinatra::Decompile is deprecated without replacement."

def warn(message)
  super "#{caller.first[/^[^:]:\d+:/]} warning: #{message}"
end
