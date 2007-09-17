class Array
  def to_hash
    self.inject({}) { |h, (k, v)|  h[k] = v; h }
  end
end
