# encoding: UTF-8
require File.expand_path('../helper', __FILE__)

class RbxTest < Test::Unit::TestCase
  it 'fails on rbx' do
    mock_app { enable(:inline_templates) }
    assert_equal "this is foo\n", @app.templates[:foo][0]
  end
end

__END__

@@ foo
this is foo
