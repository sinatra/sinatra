class Proc
  def to_result(cx, *args)
    cx.instance_eval(&self)
  end
end

class String
  def to_result(cx, *args)
    cx.body self
  end
end

class Array
  def to_result(cx, *args)
    self.shift.to_result(cx, *self)
  end
end

class Symbol
  def to_result(cx, *args)
    cx.send(self, *args)
  end
end

class Fixnum
  def to_result(cx, *args)
    cx.status self
    cx.body args.first
  end
end
