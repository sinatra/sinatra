# Sinatra

*注：本文档是英文版的翻译，内容更新有可能不及时。
如有不一致的地方，请以英文版为准。*

Sinatra是一个基于Ruby语言的[DSL](https://en.wikipedia.org/wiki/Domain-specific_language)（
领域专属语言），可以轻松、快速的创建web应用。

~~~~ruby
# myapp.rb
require 'sinatra'

get '/' do
  'Hello world!'
end
~~~~

安装gem，然后运行：

~~~~shell
gem install sinatra
ruby myapp.rb
~~~~

在该地址查看： http://localhost:4567

这个时候访问地址将绑定到 127.0.0.1 和 localhost ，如果使用 vagrant 进行开发，访问会失败，此时就需要进行 ip 绑定了：

~~~~shell
ruby myapp.rb -o 0.0.0.0
~~~~

```-o``` 这个参数就是进行 Listening 时候监听的绑定，能从通过 IP、127.0.0.1、localhost + 端口号进行访问。

安装Sintra后，最好再运行`gem install thin`安装Thin。这样，Sinatra会优先选择Thin作为服务器。

## 目录

* [Sinatra](#sinatra)
    * [目录](#目录)
    * [路由(route)](#路由route)
    * [条件](#条件)
    * [返回值](#返回值)
    * [自定义路由匹配器](#自定义路由匹配器)
    * [静态文件](#静态文件)
    * [视图 / 模板](#视图--模板)
        * [字面值模板](#字面值模板)
        * [可用的模板语言](#可用的模板语言)
            * [Haml 模板](#haml-模板)
            * [Erb 模板](#erb-模板)
            * [Builder 模板](#builder-模板)
            * [Nokogiri 模板](#nokogiri-模板)
            * [Sass 模板](#sass-模板)
            * [SCSS 模板](#scss-模板)
            * [Less 模板](#less-模板)
            * [Liquid 模板](#liquid-模板)
            * [Markdown 模板](#markdown-模板)
            * [Textile 模板](#textile-模板)
            * [RDoc 模板](#rdoc-模板)
            * [AsciiDoc 模板](#asciidoc-模板)
            * [Radius 模板](#radius-模板)
            * [Markaby 模板](#markaby-模板)
            * [RABL 模板](#rabl-模板)
            * [Slim 模板](#slim-模板)
            * [Creole 模板](#creole-模板)
            * [MediaWiki 模板](#mediawiki-模板)
            * [CoffeeScript 模板](#coffeescript-模板)
            * [Stylus 模板](#stylus-模板)
            * [Yajl 模板](#yajl-模板)
            * [WLang 模板](#wlang-模板)
        * [在模板中访问变量](#在模板中访问变量)
        * [含 `yield` 的模板和嵌套布局](#含-yield-的模板和嵌套布局)
        * [内联模板](#内联模板)
        * [具名模板](#具名模板)
        * [关联文件扩展名](#关联文件扩展名)
        * [添加你自己的模版引擎](#添加你自己的模版引擎)
        * [使用自定义模板查找逻辑](#使用自定义模板查找逻辑)
    * [过滤器](#过滤器)
    * [辅助方法](#辅助方法)
        * [使用 Sessions](#使用-sessions)
        * [挂起](#挂起)
        * [让路](#让路)
        * [触发另一个路由](#触发另一个路由)
        * [设定消息体，状态码和消息头](#设定消息体状态码和消息头)
        * [流式响应](#流式响应)
        * [日志](#日志)
        * [媒体(MIME)类型](#媒体mime类型)
        * [生成 URL](#生成-url)
        * [浏览器重定向](#浏览器重定向)
        * [缓存控制](#缓存控制)
        * [发送文件](#发送文件)
        * [访问请求对象](#访问请求对象)
        * [附件](#附件)
        * [处理日期时间](#处理日期时间)
        * [查找模板文件](#查找模板文件)
    * [配置](#配置)
        * [配置攻击保护](#配置攻击保护)
        * [可选的设置](#可选的设置)
    * [环境](#环境)
    * [错误处理](#错误处理)
        * [未找到](#未找到)
        * [错误](#错误)
    * [Rack 中间件](#rack-中间件)
    * [测试](#测试)
    * [Sinatra::Base - 中间件，程序库和模块化应用](#sinatrabase---中间件程序库和模块化应用)
        * [模块化 vs. 传统的方式](#模块化-vs-传统的方式)
        * [运行一个模块化应用](#运行一个模块化应用)
        * [使用config.ru运行传统方式的应用](#使用configru运行传统方式的应用)
        * [什么时候用 config.ru?](#什么时候用-configru)
        * [把Sinatra当成中间件来使用](#把sinatra当成中间件来使用)
        * [动态应用程序创建](#动态应用程序创建)
    * [变量域和绑定](#变量域和绑定)
        * [应用/类 变量域](#应用类-变量域)
        * [请求/实例 变量域](#请求实例-变量域)
        * [代理变量域](#代理变量域)
    * [命令行](#命令行)
        * [多线程](#多线程)
    * [必要条件](#必要条件)
    * [紧追前沿](#紧追前沿)
        * [通过Bundler](#通过bundler)
        * [使用自己的](#使用自己的)
        * [全局安装](#全局安装)
    * [版本号](#版本号)
    * [更多](#更多)

## 路由(route)

在Sinatra中，一个路由分为两部分：HTTP方法(GET, POST等)和URL匹配范式。
每个路由都有一个要执行的代码块：

~~~~ruby
get '/' do
  .. 显示内容 ..
end

post '/' do
  .. 创建内容 ..
end

put '/' do
  .. 更新内容 ..
end

patch '/' do
  .. 修改内容 ..
end

delete '/' do
  .. 删除内容 ..
end

options '/' do
  .. 显示命令列表 ..
end

link '/' do
  .. 建立某种联系 ..
end

unlink '/' do
  .. 解除某种联系 ..
end


~~~~

路由按照它们被定义的顺序进行匹配。 第一个与请求匹配的路由会被调用。

路由范式可以包括具名参数，可通过`params`哈希表获得：

~~~~ruby
get '/hello/:name' do
  # 匹配 "GET /hello/foo" 和 "GET /hello/bar"
  # params['name'] 的值是 'foo' 或者 'bar'
  "Hello #{params['name']}!"
end
~~~~

你同样可以通过代码块参数获得具名参数：

~~~~ruby
get '/hello/:name' do |n|
  # n 存储了 params['name']
  "Hello #{n}!"
end
~~~~

路由范式也可以包含通配符参数， 可以通过`params['splat']`数组获得。

~~~~ruby
get '/say/*/to/*' do
  # 匹配 /say/hello/to/world
  params['splat'] # => ["hello", "world"]
end

get '/download/*.*' do
  # 匹配 /download/path/to/file.xml
  params['splat'] # => ["path/to/file", "xml"]
end
~~~~

或者使用代码块参数:

~~~~ruby
get '/download/*.*' do |path, ext|
  [path, ext] # => ["path/to/file", "xml"]
end
~~~~

通过正则表达式匹配的路由：

~~~~ruby
get /\A\/hello\/([\w]+)\z/ do
  "Hello, #{params['captures'].first}!"
end
~~~~

或者使用代码块参数：

~~~~ruby
get %r{/hello/([\w]+)} do |c|
  # 匹配 "GET /meta/hello/world", "GET /hello/world/1234" 等
  "Hello, #{c}!"
end
~~~~

## 条件

路由也可以包含多样的匹配条件，比如user agent：

~~~~ruby
get '/foo', :agent => /Songbird (\d\.\d)[\d\/]*?/ do
  "你正在使用Songbird，版本是 #{params['agent'][0]}"
end

get '/foo' do
  # 匹配除Songbird以外的浏览器
end
~~~~

其他可选的条件是 `host_name` 和 `provides`：

~~~~ruby
get '/', :host_name => /^admin\./ do
  "管理员区域，无权进入！"
end

get '/', :provides => 'html' do
  haml :index
end

get '/', :provides => ['rss', 'atom', 'xml'] do
  builder :feed
end
~~~~

`provides` 会查找请求头部的 Accept 字段。

你也可以自定义条件：

~~~~ruby
set(:probability) { |value| condition { rand <= value } }

get '/win_a_car', :probability => 0.1 do
  "You won!"
end

get '/win_a_car' do
  "Sorry, you lost."
end
~~~~

如果一个条件需要多个参数，用 splat 操作符（即`*arg`形式）实现：

```ruby
set(:auth) do |*roles|   # <- 注意这里的 splat 操作符
  condition do
    unless logged_in? && roles.any? {|role| current_user.in_role? role }
      redirect "/login/", 303
    end
  end
end

get "/my/account/", :auth => [:user, :admin] do
  "Your Account Details"
end

get "/only/admin/", :auth => :admin do
  "Only admins are allowed here!"
end
```

## 返回值

路由代码块的返回值至少决定了返回给HTTP客户端的响应体，
或者至少决定了在Rack堆栈中的下一个中间件。
大多数情况下，将是一个字符串，就像上面的例子中的一样。
但是其他值也是可以接受的。

你可以返回任何对象，或者是一个合理的Rack响应， Rack
body对象或者HTTP状态码：

-   一个包含三个元素的数组:
    `[状态 (Fixnum), 头 (Hash), 响应体 (回应 #each)]`

-   一个包含两个元素的数组: `[状态 (Fixnum), 响应体 (回应 #each)]`

-   一个能够回应 `#each` ，只传回字符串的对象

-   一个代表状态码的数字

那样，我们可以轻松的实现例如流式传输的例子：

~~~~ruby
class Stream
  def each
    100.times { |i| yield "#{i}\n" }
  end
end

get('/') { Stream.new }
~~~~

你也可以使用 `stream` 辅助方法（在后面描述）
来简化代码并将流逻辑嵌入路由中。

## 自定义路由匹配器

如上显示，Sinatra内置了对于使用字符串和正则表达式作为路由匹配的支持。
但是，它并没有只限于此。 你可以非常容易地定义你自己的匹配器:

~~~~ruby
class AllButPattern
  Match = Struct.new(:captures)

  def initialize(except)
    @except   = except
    @captures = Match.new([])
  end

  def match(str)
    @captures unless @except === str
  end
end

def all_but(pattern)
  AllButPattern.new(pattern)
end

get all_but("/index") do
  # ...
end
~~~~

上面的例子可能太繁琐了， 因为它也可以用更简单的方式表述:

~~~~ruby
get // do
  pass if request.path_info == "/index"
  # ...
end
~~~~

或者，使用消极向前查找:

~~~~ruby
get %r{^(?!/index$)} do
  # ...
end
~~~~

## 静态文件

静态文件是从 `./public` 目录提供服务。你可以通过设置`:public_folder`
选项设定一个不同的位置：

~~~~ruby
set :public_folder, File.dirname(__FILE__) + '/static'
~~~~

请注意public目录名并没有被包含在URL之中。文件
`./public/css/style.css`是通过
`http://example.com/css/style.css`地址访问的。

使用 `:static_cache_control` 设置（见下文）来添加
`Cache-Control` 头信息。

## 视图 / 模板

每一种模板语言都通过自己的渲染方法来使用。
这些方法简单地返回一个字符串：

```ruby
get '/' do
  erb :index
end
```

这会渲染 `views/index.erb`。

除了模板名以外，你也可以直接传入模板内容：

```ruby
get '/' do
  code = "<%= Time.now %>"
  erb code
end
```

模板接受第二个参数，即选项哈希表：

```ruby
get '/' do
  erb :index, :layout => :post
end
```

这将渲染 `views/index.erb` 并嵌入于 `views/post.erb` 中
（如果存在的话，默认值为 `views/layout.erb`）。

任何不被 Sinatra 接受的选项将会被传给模板引擎：

```ruby
get '/' do
  haml :index, :format => :html5
end
```

你也可以为每种模板语言从总体上设置选项：

```ruby
set :haml, :format => :html5

get '/' do
  haml :index
end
```

传给渲染方法的选项会覆盖通过 `set` 设置的选项。

可用选项：

<dl>
  <dt>locals</dt>
  <dd>
    传给文档的局部变量列表。和局部模板一起用很方便。
    例： <tt>erb "<%= foo %>", :locals => {:foo => "bar"}</tt>
  </dd>

  <dt>default_encoding</dt>
  <dd>
    不确定情况下使用的字符串编码。默认为
    <tt>settings.default_encoding</tt>.
  </dd>

  <dt>views</dt>
  <dd>
    加载模板所在的视图文件夹，默认为 <tt>settings.views</tt>。
  </dd>

  <dt>layout</dt>
  <dd>
    是否使用布局(<tt>true</tt> 或 <tt>false</tt>).
    如果为 Symbol,指定用什么模板。例：
    <tt>erb :index, :layout => !request.xhr?</tt>
  </dd>

  <dt>content_type</dt>
  <dd>
    模板生成的 Content-Type. 默认值依赖与模板语言。
  </dd>

  <dt>scope</dt>
  <dd>
    渲染模板时所用的作用域。默认为应用实例。
    如果你改变了它，实例变量和辅助方法将不再可用。
  </dd>

  <dt>layout_engine</dt>
  <dd>
    渲染布局使用的模板引擎。对不支持布局的语言很有用。
    默认值是渲染模板所用的引擎。例：
    <tt>set :rdoc, :layout_engine => :erb</tt>
  </dd>

  <dt>layout_options</dt>
  <dd>
    只用于渲染布局的特殊选项。例：
    <tt>set :rdoc, :layout_options => { :views => 'views/layouts' }</tt>
  </dd>
</dl>

模板被认为直接放在 `./views` 目录下。
使用一个不同的视图目录：

```ruby
set :views, settings.root + '/templates'
```

须记住你总该用 symbol 来引用模板，即使它们位于子目录中
（在这种情况下，使用： `:'subdir/template'` 或 `'subdir/template'.to_sym` ）。
你必须使用 symbol ，否则渲染方法会直接渲染传给它们的字符串。

### 字面值模板

```ruby
get '/' do
  haml '%div.title Hello World'
end
```

渲染模板字符串。

### 可用的模板语言

一些语言有多种实现。为了指定使用那个实现（并为了线程安全），你应该首先包含它：

```ruby
require 'rdiscount' # 或 require 'bluecloth'
get('/') { markdown :index }
```

#### Haml 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://haml.info/" title="haml">haml</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.haml</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>haml :index, :format => :html5</tt></td>
  </tr>
</table>

#### Erb 模板

<table>
  <tr>
    <td>依赖</td>
    <td>
      <a href="http://www.kuwata-lab.com/erubis/" title="erubis">erubis</a>
      或 erb (包括在 Ruby 中)
    </td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.erb</tt>, <tt>.rhtml</tt> 或 <tt>.erubis</tt> (仅限 Erubis)</td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>erb :index</tt></td>
  </tr>
</table>

#### Builder 模板

<table>
  <tr>
    <td>依赖</td>
    <td>
      <a href="https://github.com/jimweirich/builder" title="builder">builder</a>
    </td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.builder</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>builder { |xml| xml.em "hi" }</tt></td>
  </tr>
</table>

对内联模板也接受一个代码块（见例子）。

#### Nokogiri 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://www.nokogiri.org/" title="nokogiri">nokogiri</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.nokogiri</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>nokogiri { |xml| xml.em "hi" }</tt></td>
  </tr>
</table>

对内联模板也接受一个代码块（见例子）。

#### Sass 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://sass-lang.com/" title="sass">sass</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.sass</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>sass :stylesheet, :style => :expanded</tt></td>
  </tr>
</table>

#### SCSS 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://sass-lang.com/" title="sass">sass</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.scss</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>scss :stylesheet, :style => :expanded</tt></td>
  </tr>
</table>

#### Less 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://lesscss.org/" title="less">less</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.less</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>less :stylesheet</tt></td>
  </tr>
</table>

#### Liquid 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://liquidmarkup.org/" title="liquid">liquid</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.liquid</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>liquid :index, :locals => { :key => 'value' }</tt></td>
  </tr>
</table>

因为在 Liquid 模板中你无法调用 Ruby 方法（除了 `yield`），
你几乎总是想要传递局部变量(通过 locals 选项)给它。

#### Markdown 模板

<table>
  <tr>
    <td>依赖</td>
    <td>
      以下任何一个:
        <a href="https://github.com/davidfstr/rdiscount" title="RDiscount">RDiscount</a>,
        <a href="https://github.com/vmg/redcarpet" title="RedCarpet">RedCarpet</a>,
        <a href="http://deveiate.org/projects/BlueCloth" title="BlueCloth">BlueCloth</a>,
        <a href="http://kramdown.gettalong.org/" title="kramdown">kramdown</a>,
        <a href="https://github.com/bhollis/maruku" title="maruku">maruku</a>
    </td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.markdown</tt>, <tt>.mkd</tt> and <tt>.md</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>markdown :index, :layout_engine => :erb</tt></td>
  </tr>
</table>

不可能在 markdown 中调用方法，也不能向其传递局部变量。
所以通常和其他渲染引擎结合使用：

```ruby
erb :overview, :locals => { :text => markdown(:introduction) }
```

注意你也可以在其他模板中调用 `markdown` 方法：

```ruby
%h1 Hello From Haml!
%p= markdown(:greetings)
```

因为你不能在 Markdown 中调用 Ruby ，你不能使用 Markdown 写的布局。但是，通过 `:layout_engine` 选项，
可以使用不同的渲染引擎渲染模板和布局。

#### Textile 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://redcloth.org/" title="RedCloth">RedCloth</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.textile</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>textile :index, :layout_engine => :erb</tt></td>
  </tr>
</table>

不可能在 textile 中调用方法，也不能向其传递局部变量。
所以通常和其他渲染引擎结合使用：

```ruby
erb :overview, :locals => { :text => textile(:introduction) }
```

注意你也可以在其他模板中调用 `textile` 方法：

```ruby
%h1 Hello From Haml!
%p= textile(:greetings)
```

因为你不能在 Textile 中调用 Ruby ，你不能使用 Textile 写的布局。但是，通过 `:layout_engine` 选项，
可以使用不同的渲染引擎渲染模板和布局。

#### RDoc 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://rdoc.sourceforge.net/" title="RDoc">RDoc</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.rdoc</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>rdoc :README, :layout_engine => :erb</tt></td>
  </tr>
</table>

不可能在 rdoc 中调用方法，也不能向其传递局部变量。
所以通常和其他渲染引擎结合使用：

```ruby
erb :overview, :locals => { :text => rdoc(:introduction) }
```

注意你也可以在其他模板中调用 `rdoc` 方法：

```ruby
%h1 Hello From Haml!
%p= rdoc(:greetings)
```

因为你不能在 RDoc 中调用 Ruby ，你不能使用 Rdoc 写的布局。但是，通过 `:layout_engine` 选项，
可以使用不同的渲染引擎渲染模板和布局。

#### AsciiDoc 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://asciidoctor.org/" title="Asciidoctor">Asciidoctor</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.asciidoc</tt>, <tt>.adoc</tt> and <tt>.ad</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>asciidoc :README, :layout_engine => :erb</tt></td>
  </tr>
</table>

因为在 AsciiDoc 模板中你无法直接调用 Ruby 方法，
你几乎总是想要传递局部变量给它。

#### Radius 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="https://github.com/jlong/radius" title="Radius">Radius</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.radius</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>radius :index, :locals => { :key => 'value' }</tt></td>
  </tr>
</table>

因为在 Radius 模板中你无法直接调用 Ruby 方法，
你几乎总是想要传递局部变量给它。

#### Markaby 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://markaby.github.io/" title="Markaby">Markaby</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.mab</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>markaby { h1 "Welcome!" }</tt></td>
  </tr>
</table>

对于内联模板它也接受一个代码块（见例子）。

#### RABL 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="https://github.com/nesquena/rabl" title="Rabl">Rabl</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.rabl</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>rabl :index</tt></td>
  </tr>
</table>

#### Slim 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="http://slim-lang.com/" title="Slim Lang">Slim Lang</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.slim</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>slim :index</tt></td>
  </tr>
</table>

#### Creole 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="https://github.com/minad/creole" title="Creole">Creole</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.creole</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>creole :wiki, :layout_engine => :erb</tt></td>
  </tr>
</table>

不可能在 creole 中调用方法，也不可能向其传递局部变量。
因此通常和其他渲染引擎结合使用：

```ruby
erb :overview, :locals => { :text => creole(:introduction) }
```

注意你也可以在其他模板中调用 `creole` 方法：

```ruby
%h1 Hello From Haml!
%p= creole(:greetings)
```

因为你不能在 Creole 中调用 Ruby ，你不能使用 Creole 写的布局。但是，通过 `:layout_engine` 选项，
可以使用不同的渲染引擎渲染模板和布局。

#### MediaWiki 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="https://github.com/nricciar/wikicloth" title="WikiCloth">WikiCloth</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.mediawiki</tt> and <tt>.mw</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>mediawiki :wiki, :layout_engine => :erb</tt></td>
  </tr>
</table>

不可能在 MediaWiki 标记中调用方法，也不可能向其传递局部变量。
因此通常和其他渲染引擎结合使用：

```ruby
erb :overview, :locals => { :text => mediawiki(:introduction) }
```

注意你也可以在其他模板中调用 `mediawiki` 方法：

```ruby
%h1 Hello From Haml!
%p= mediawiki(:greetings)
```

因为你不能在 MediaWiki 中调用 Ruby ，你不能使用 MediaWiki 写的布局。但是，通过 `:layout_engine` 选项，
可以使用不同的渲染引擎渲染模板和布局。

#### CoffeeScript 模板

<table>
  <tr>
    <td>依赖</td>
    <td>
      <a href="https://github.com/josh/ruby-coffee-script" title="Ruby CoffeeScript">
        CoffeeScript
      </a> 和一个
      <a href="https://github.com/sstephenson/execjs/blob/master/README.md#readme" title="ExecJS">
        执行 javascript 的方法
      </a>
    </td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.coffee</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>coffee :index</tt></td>
  </tr>
</table>

#### Stylus 模板

<table>
  <tr>
    <td>依赖</td>
    <td>
      <a href="https://github.com/forgecrafted/ruby-stylus" title="Ruby Stylus">
        Stylus
      </a> 和一个
      <a href="https://github.com/sstephenson/execjs/blob/master/README.md#readme" title="ExecJS">
        执行 javascript 的方法
      </a>
    </td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.styl</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>stylus :index</tt></td>
  </tr>
</table>

Before being able to use Stylus templates, you need to load `stylus` and
`stylus/tilt` first:
在使用 Stylus 模板前，你需要首先加载 `stylus` 和 `stylus/tilt`：

```ruby
require 'sinatra'
require 'stylus'
require 'stylus/tilt'

get '/' do
  stylus :example
end
```

#### Yajl 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="https://github.com/brianmario/yajl-ruby" title="yajl-ruby">yajl-ruby</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.yajl</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td>
      <tt>
        yajl :index,
             :locals => { :key => 'qux' },
             :callback => 'present',
             :variable => 'resource'
      </tt>
    </td>
  </tr>
</table>

模板源代码作为 Ruby 字符串被求值，并且作为结果的 json 变量由 `#to_json` 转换：

```ruby
json = { :foo => 'bar' }
json[:baz] = key
```

`:callback` 和 `:variable` 选项可用来装饰渲染后的对象：

```javascript
var resource = {"foo":"bar","baz":"qux"};
present(resource);
```

#### WLang 模板

<table>
  <tr>
    <td>依赖</td>
    <td><a href="https://github.com/blambeau/wlang/" title="WLang">WLang</a></td>
  </tr>
  <tr>
    <td>文件扩展名</td>
    <td><tt>.wlang</tt></td>
  </tr>
  <tr>
    <td>例子</td>
    <td><tt>wlang :index, :locals => { :key => 'value' }</tt></td>
  </tr>
</table>

因为在 WLang 中调用 ruby 方法并不符合语言习惯，你几乎总是想要传递局部变量给它。
尽管如此，用 WLang 写的布局和 `yield` 是支持的。

### 在模板中访问变量

模板和路由执行器在同样的上下文求值。
在路由执行器中赋值的实例变量可以直接被模板访问。

~~~~ruby
get '/:id' do
  @foo = Foo.find(params['id'])
  haml '%h1= @foo.name'
end
~~~~

或者，显式地指定一个局部变量的哈希：

~~~~ruby
get '/:id' do
  foo = Foo.find(params['id'])
  haml '%h1= foo.name', :locals => { :foo => foo }
end
~~~~

典型的使用情况是在别的模板中按照局部模板的方式来填充。

### 含 `yield` 的模板和嵌套布局

一个布局通常只是一个调用 `yield` 的模板。
这样一个模板既可以像上面描述的一样通过 `:template` 选项使用，
也可以向下面一样用代码块渲染：

```ruby
erb :post, :layout => false do
  erb :index
end
```

这段代码几乎与 `erb :index, :layout => :post` 等价。

向渲染方法传递代码块是创建嵌套布局的最有用方法：

```ruby
erb :main_layout, :layout => false do
  erb :admin_layout do
    erb :user
  end
end
```

这也可以用更短的代码实现：

```ruby
erb :admin_layout, :layout => :main_layout do
  erb :user
end
```

目前，以下渲染方法接受一个代码块： `erb`, `haml`,
`liquid`, `slim `, `wlang`.
通用的 `render` 方法也接受一个代码块。

### 内联模板

模板可以在源文件的末尾定义：

~~~~ruby
require 'sinatra'

get '/' do
  haml :index
end

__END__

@@ layout
%html
  = yield

@@ index
%div.title Hello world.
~~~~

注意：引入sinatra的源文件中定义的内联模板才能被自动载入。
如果你在其他源文件中有内联模板，
需要显式执行调用`enable :inline_templates`。

### 具名模板

模板可以通过使用顶层 `template` 方法定义：

~~~~ruby
template :layout do
  "%html\n  =yield\n"
end

template :index do
  '%div.title Hello World!'
end

get '/' do
  haml :index
end
~~~~

如果存在名为“layout”的模板，该模板会在每个模板填充的时候被使用。
你可以通过传送 `:layout => false`分别禁用，
或者通过`set :haml, :layout => false`来默认禁用他们。

~~~~ruby
get '/' do
  haml :index, :layout => !request.xhr?
end
~~~~

### 关联文件扩展名

为了关联一个文件扩展名到一个模版引擎，使用
`Tilt.register`。比如，如果你喜欢使用 `tt`
作为Textile模版的扩展名，你可以这样做:

~~~~ruby
Tilt.register :tt, Tilt[:textile]
~~~~

### 添加你自己的模版引擎

首先，通过Tilt注册你自己的引擎，然后创建一个填充方法:

~~~~ruby
Tilt.register :myat, MyAwesomeTemplateEngine

helpers do
  def myat(*args) render(:myat, *args) end
end

get '/' do
  myat :index
end
~~~~

这里调用的是 `./views/index.myat`。察看
[github.com/rtomayko/tilt](https://github.com/rtomayko/tilt)
来更多了解Tilt.

### 使用自定义模板查找逻辑

为了实现你自己的模板查找机制你可以编写你自己的 `#find_template` 方法：

```ruby
configure do
  set :views [ './views/a', './views/b' ]
end

def find_template(views, name, engine, &block)
  Array(views).each do |v|
    super(v, name, engine, &block)
  end
end
```

## 过滤器

前置过滤器在每个请求前，在请求的上下文环境中被执行，
而且可以修改请求和响应。 在过滤器中设定的实例变量可以被路由和模板访问：

~~~~ruby
before do
  @note = 'Hi!'
  request.path_info = '/foo/bar/baz'
end

get '/foo/*' do
  @note #=> 'Hi!'
  params['splat'] #=> 'bar/baz'
end
~~~~

后置过滤器在每个请求之后，在请求的上下文环境中执行，
而且可以修改请求和响应。
在前置过滤器和路由中设定的实例变量可以被后置过滤器访问：

~~~~ruby
after do
  puts response.status
end
~~~~

请注意：除非你显式使用 `body` 方法，而不是在路由中直接返回字符串，
消息体在后置过滤器是不可用的， 因为它在之后才会生成。

过滤器可以可选地带有范式， 只有请求路径满足该范式时才会执行：

~~~~ruby
before '/protected/*' do
  authenticate!
end

after '/create/:slug' do |slug|
  session['last_slug'] = slug
end
~~~~

和路由一样，过滤器也可以带有条件:

~~~~ruby
before :agent => /Songbird/ do
  # ...
end

after '/blog/*', :host_name => 'example.com' do
  # ...
end
~~~~

## 辅助方法

使用顶层的 `helpers` 方法来定义辅助方法，以便在路由处理器和模板中使用：

~~~~ruby
helpers do
  def bar(name)
    "#{name}bar"
  end
end

get '/:name' do
  bar(params['name'])
end
~~~~

此外，辅助方法也可在模块中分别定义：

```ruby
module FooUtils
  def foo(name) "#{name}foo" end
end

module BarUtils
  def bar(name) "#{name}bar" end
end

helpers FooUtils, BarUtils
```

效果和在应用类(application class)里包含这些模块相同。

### 使用 Sessions

Session被用来在请求之间保持状态。如果被激活，每一个用户会话
对应有一个session哈希:

~~~~ruby
enable :sessions

get '/' do
  "value = " << session['value'].inspect
end

get '/:value' do
  session['value'] = params['value']
end
~~~~

请注意 `enable :sessions` 实际上保存所有的数据在一个cookie之中。
这可能不会总是你想要的（比如，保存大量的数据会增加你的流量）。
你可以使用任何的Rack session中间件，为了这么做， \*不要\*调用
`enable :sessions`，而是 按照自己的需要引入你的中间件：

~~~~ruby
use Rack::Session::Pool, :expire_after => 2592000

get '/' do
  "value = " << session['value'].inspect
end

get '/:value' do
  session['value'] = params['value']
end
~~~~

为了增强安全性，cookie 中的 session 数据被 session 密钥签名。
Sinatra 会为你生成一个随机的密钥。
但是，这个密钥在每次启动应用时会改变，你可能希望自己设置一个密钥，
使你所有的应用实例都共享它：

```ruby
set :session_secret, 'super secret'
```

如果你希望更进一步设置，你可以在 `sessions` 设置中存储选项的哈希：

```ruby
set :sessions, :domain => 'foo.com'
```

为了在 foo.com 的子域名下的其他应用间共享 session，
像这样给域名加上一个 *.* 前缀：

```ruby
set :sessions, :domain => '.foo.com'
```


### 挂起

要想直接地停止请求，在过滤器或者路由中使用：

~~~~ruby
halt
~~~~

你也可以指定挂起时的状态码：

~~~~ruby
halt 410
~~~~

或者消息体：

~~~~ruby
halt 'this will be the body'
~~~~

或者两者;

~~~~ruby
halt 401, 'go away!'
~~~~

也可以带消息头：

~~~~ruby
halt 402, {'Content-Type' => 'text/plain'}, 'revenge'
~~~~

当然也可以将`halt`与模板结合：

```ruby
halt erb(:error)
```

### 让路

一个路由可以放弃处理，将处理让给下一个匹配的路由，使用 `pass`：

~~~~ruby
get '/guess/:who' do
  pass unless params['who'] == 'Frank'
  'You got me!'
end

get '/guess/*' do
  'You missed!'
end
~~~~

路由代码块被直接退出，控制流继续前进到下一个匹配的路由。
如果没有匹配的路由，将返回404。

### 触发另一个路由

有些时候，`pass` 并不是你想要的，你希望得到的是另一个路由的结果。
只要使用 `call` 就可以做到这一点:

~~~~ruby
get '/foo' do
  status, headers, body = call env.merge("PATH_INFO" => '/bar')
  [status, headers, body.map(&:upcase)]
end

get '/bar' do
  "bar"
end
~~~~

请注意在以上例子中，你可以更加简化测试并增加性能，只需移动
`"bar"`到一个被`/foo`和 `/bar`同时使用的辅助方法。

如果你希望请求被发送到同一个应用实例，而不是副本， 使用 `call!` 而不是
`call`.

如果想更多了解 `call`，请察看 Rack specification。

### 设定消息体，状态码和消息头

通过路由代码块的返回值来设定状态码和消息体不仅是可能的，而且是推荐的。
但是，在某些场景中你可能想在作业流程中的特定点上设置消息体。 你可以通过
`body` 辅助方法这么做。 如果你这样做了，
你可以在那以后使用该方法获得消息体:

~~~~ruby
get '/foo' do
  body "bar"
end

after do
  puts body
end
~~~~

也可以传一个代码块给 `body`，它将会被Rack处理器执行（
这将可以被用来实现streaming，参见“返回值”）。

和消息体类似，你也可以设定状态码和消息头:

~~~~ruby
get '/foo' do
  status 418
  headers \
    "Allow"   => "BREW, POST, GET, PROPFIND, WHEN",
    "Refresh" => "Refresh: 20; http://www.ietf.org/rfc/rfc2324.txt"
  body "I'm a tea pot!"
end
~~~~

如同 `body`, 不带参数的 `headers` 和 `status` 可以用来访问
他们的当前值.

### 流式响应

有些时候，你想在生成消息体部分的同时开始送出数据。
在极端情况下，你想持续发送数据直到客户端关闭链接。
你可以使用 `stream` 辅助方法来避免构造自己的包装：

```ruby
get '/' do
  stream do |out|
    out << "It's gonna be legen -\n"
    sleep 0.5
    out << " (wait for it) \n"
    sleep 1
    out << "- dary!\n"
  end
end
```

这允许你实现流 API，[Server Sent Events](https://w3c.github.io/eventsource/),
并可用作 [WebSockets](https://en.wikipedia.org/wiki/WebSocket)的基础。
这也可以用来在部分内容依赖缓慢的资源时提高通量。

注意流的行为，尤其是并发请求数，很大程度上依赖用来服务应用的网络服务器。
一些服务器可能甚至完全不支持流。如果服务器不支持流，
消息体会在传给 `stream` 的代码库结束执行后立刻发送。
流完全不能在 Shotgun 工作。

如果可选参数被设为 `keep_open`, 将不会对流对象调用 `close`，
这允许你在之后任意时间点在执行流中关闭它。这只在 evented server 工作，如 Thin 和 Rainbows。
其他服务器依然会关闭流：

```ruby
# long polling

set :server, :thin
connections = []

get '/subscribe' do
  # register a client's interest in server events
  stream(:keep_open) do |out|
    connections << out
    # purge dead connections
    connections.reject!(&:closed?)
  end
end

post '/:message' do
  connections.each do |out|
    # notify client that a new message has arrived
    out << params['message'] << "\n"

    # indicate client to connect again
    out.close
  end

  # acknowledge
  "message received"
end
```

### 日志

在请求作用域，`logger` 辅助函数暴露一个 `Logger` 实例：

```ruby
get '/' do
  logger.info "loading data"
  # ...
end
```

日志记录器会自动考虑你的 Rack 处理器的日志设定。
如果日志被禁用，这个方法会返回哑对象，所以你不用在你的路由处理器和过滤器中担心它。

注意日志只为 `Sinatra::Application` 默认启用，所以如果你继承了 `Sinatra::Base`,
你可能想要自己启用它。

```ruby
class MyApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end
end
```

要避免任何日志中间件被创建，设置 `logging` 为 `nil`。
但是，记住这种情况下 `logger` 将返回 `nil`。
一个通常的用例是你想设置自己的日志记录器。
Sinatra 会使用它在 `env['rack.logger']` 找到的东西。

### 媒体(MIME)类型

使用 `send_file` 或者静态文件的时候，Sinatra可能不能识别你的媒体类型。
使用 `mime_type` 通过文件扩展名来注册它们：

```ruby
configure do
  mime_type :foo, 'text/foo'
end
```

你也可以使用 `content_type` 辅助方法：

~~~~ruby
get '/' do
  content_type :foo
  "foo foo foo"
end
~~~~

### 生成 URL

为了生成URL，你需要使用 `url` 辅助方法， 例如，在Haml中:

~~~~ruby
%a{:href => url('/foo')} foo
~~~~

如果使用反向代理和Rack路由，生成URL的时候会考虑这些因素。

这个方法还有一个别名 `to` (见下面的例子).

### 浏览器重定向

你可以通过 `redirect` 辅助方法触发浏览器重定向:

~~~~ruby
get '/foo' do
  redirect to('/bar')
end
~~~~

其他参数的用法，与 `halt`相同:

~~~~ruby
redirect to('/bar'), 303
redirect 'http://www.google.com/', 'wrong place, buddy'
~~~~

用 `redirect back`可以把用户重定向到原始页面:

~~~~ruby
get '/foo' do
  "<a href='/bar'>do something</a>"
end

get '/bar' do
  do_something
  redirect back
end
~~~~

如果想传递参数给redirect，可以用query string:

~~~~ruby
redirect to('/bar?sum=42')
~~~~

或者用session:

~~~~ruby
enable :sessions

get '/foo' do
  session['secret'] = 'foo'
  redirect to('/bar')
end

get '/bar' do
  session['secret']
end
~~~~

### 缓存控制

要使用HTTP缓存，必须正确地设定消息头。

你可以这样设定 Cache-Control 消息头:

~~~~ruby
get '/' do
  cache_control :public
  "cache it!"
end
~~~~

核心提示: 在前置过滤器中设定缓存.

~~~~ruby
before do
  cache_control :public, :must_revalidate, :max_age => 60
end
~~~~

如果你正在用 `expires` 辅助方法设定对应的消息头 `Cache-Control`
会自动设定：

~~~~ruby
before do
  expires 500, :public, :must_revalidate
end
~~~~

为了合适地使用缓存，你应该考虑使用 `etag` 和 `last_modified`方法。
推荐在执行繁重任务\*之前\*使用这些helpers，这样一来，
如果客户端在缓存中已经有相关内容，就会立即得到显示。


~~~~ruby
get '/article/:id' do
  @article = Article.find params['id']
  last_modified @article.updated_at
  etag @article.sha1
  erb :article
end
~~~~

使用 [weak
ETag](https://en.wikipedia.org/wiki/HTTP_ETag#Strong_and_weak_validation)
也是有可能的:

~~~~ruby
etag @article.sha1, :weak
~~~~

这些辅助方法并不会为你做任何缓存，而是将必要的信息传送给你的缓存
如果你在寻找缓存的快速解决方案，试试
[rack-cache](https://github.com/rtomayko/rack-cache):

~~~~ruby
require "rack/cache"
require "sinatra"

use Rack::Cache

get '/' do
  cache_control :public, :max_age => 36000
  sleep 5
  "hello"
end
~~~~

使用 `:static_cache_control` 设置（见下）来给静态文件添加
`Cache-Control` 消息头信息。

根据 RFC 2616, 你的应用应该在 If-Match 或 If-None-Match header 消息头设置为 `*` 时，
根据请求的资源是否存在表现不同。Sinatra 假设对安全的（如 get）和幂等的（如 put）
请求资源是存在的，而其他资源（如 post 请求）被当作新资源对待。
你可以通过传入 `:new_resource` 选项改变这一行为：

```ruby
get '/create' do
  etag '', :new_resource => true
  Article.create
  erb :new_article
end
```

如果你依然想用 weak ETag，传入 `:kind` 选项：

```ruby
etag '', :new_resource => true, :kind => :weak
```

### 发送文件

为了发送文件，你可以使用 `send_file` 辅助方法:

~~~~ruby
get '/' do
  send_file 'foo.png'
end
~~~~

也可以带一些选项:

~~~~ruby
send_file 'foo.png', :type => :jpg
~~~~

可用的选项有:

<dl>
    <dt>filename</dt>
    <dd>响应中的文件名，默认是真实文件的名字。</dd>

    <dt>last_modified</dt>
    <dd>Last-Modified 消息头的值，默认是文件的mtime（修改时间）。</dd>

    <dt>type</dt>
    <dd>使用的内容类型，如果没有会从文件扩展名猜测。</dd>

    <dt>disposition</dt>
    <dd>
        用于 Content-Disposition，可能的包括： <tt>nil</tt> (默认), <tt>:attachment</tt> 和
        <tt>:inline</tt>
    </dd>

    <dt>length</dt>
    <dd>Content-Length 的值，默认是文件的大小。</dd>
    
    <dt>status</dt>
    <dd>
      要发送的状态码。当发送一个静态文件作为错误页时是有用的。
      
      如果Rack处理器支持的话，Ruby进程也能使用除streaming以外的方法。
      如果你使用这个辅助方法， Sinatra会自动处理range请求。
    </dd>
</dl>


### 访问请求对象

传入的请求对象可以在请求层（过滤器，路由，错误处理） 通过 `request`
方法被访问：

~~~~ruby
# 在 http://example.com/example 上运行的应用
get '/foo' do
  t = %w[text/css text/html application/javascript]
  request.accept              # ['text/html', '*/*']
  request.accept? 'text/xml'  # true
  request.preferred_type(t)   # 'text/html'
  request.body                # 被客户端设定的请求体（见下）
  request.scheme              # "http"
  request.script_name         # "/example"
  request.path_info           # "/foo"
  request.port                # 80
  request.request_method      # "GET"
  request.query_string        # ""
  request.content_length      # request.body的长度
  request.media_type          # request.body的媒体类型
  request.host                # "example.com"
  request.get?                # true (其他动词也具有类似方法)
  request.form_data?          # false
  request["some_param"]       # 参数 some_param 的值。 [] 是 params 哈希的快捷方式。
  request.referrer            # 客户端的referrer 或者 '/'
  request.user_agent          # user agent (被 :agent 条件使用)
  request.cookies             # 浏览器 cookies 哈希
  request.xhr?                # 这是否是ajax请求？
  request.url                 # "http://example.com/example/foo"
  request.path                # "/example/foo"
  request.ip                  # 客户端IP地址
  request.secure?             # false（如果是ssl则为true）
  request.forwarded?          # true （如果是运行在反向代理之后）
  request.env                 # Rack中使用的未处理的env哈希
end
~~~~

一些选项，例如 `script_name` 或者 `path_info` 也是可写的：

~~~~ruby
before { request.path_info = "/" }

get "/" do
  "all requests end up here"
end
~~~~

`request.body` 是一个IO或者StringIO对象：

~~~~ruby
post "/api" do
  request.body.rewind  # 如果已经有人读了它
  data = JSON.parse request.body.read
  "Hello #{data['name']}!"
end
~~~~

### 附件

你可以使用 `attachment` 辅助方法来告诉浏览器响应
应当被写入磁盘而不是在浏览器中显示。

~~~~ruby
get '/' do
  attachment
  "store it!"
end
~~~~

你也可以传递一个文件名:

~~~~ruby
get '/' do
  attachment "info.txt"
  "store it!"
end
~~~~

### 处理日期时间

Sinatra 提供一个 `time_for` 辅助函数从给定值产生一个时间对象。
它也可以转换 `DateTime`, `Date` 和相似的类：

```ruby
get '/' do
  pass if Time.now > time_for('Dec 23, 2012')
  "still time"
end
```

这个方法被 `expires`, `last_modified` 等在内部使用。
因此你可以很容易地通过在你的应用中覆写 `time_for` 扩展这些方法的行为：

```ruby
helpers do
  def time_for(value)
    case value
    when :yesterday then Time.now - 24*60*60
    when :tomorrow  then Time.now + 24*60*60
    else super
    end
  end
end

get '/' do
  last_modified :yesterday
  expires :tomorrow
  "hello"
end
```

### 查找模板文件

`find_template` 辅助方法被用于在填充时查找模板文件:

~~~~ruby
find_template settings.views, 'foo', Tilt[:haml] do |file|
  puts "could be #{file}"
end
~~~~

这并不是很有用。但是在你需要重载这个方法
来实现你自己的查找机制的时候有用。 比如，如果你想支持多于一个视图目录:

~~~~ruby
set :views, ['views', 'templates']

helpers do
  def find_template(views, name, engine, &block)
    Array(views).each { |v| super(v, name, engine, &block) }
  end
end
~~~~

另一个例子是为不同的引擎使用不同的目录:

~~~~ruby
set :views, :sass => 'views/sass', :haml => 'templates', :default => 'views'

helpers do
  def find_template(views, name, engine, &block)
    _, folder = views.detect { |k,v| engine == Tilt[k] }
    folder ||= views[:default]
    super(folder, name, engine, &block)
  end
end
~~~~

你可以很容易地包装成一个扩展然后与他人分享！

请注意 `find_template` 并不会检查文件真的存在，
而是对任何可能的路径调用给入的代码块。这并不会带来性能问题，因为
`render` 会在找到文件的时候马上使用 `break` 。
同样的，模板的路径（和内容）会在除development mode以外的场合
被缓存。你应该时刻提醒自己这一点， 如果你真的想写一个非常疯狂的方法。

## 配置

运行一次，在启动的时候，在任何环境下：

~~~~ruby
configure do
  # setting one option
  set :option, 'value'

  # setting multiple options
  set :a => 1, :b => 2

  # same as `set :option, true`
  enable :option

  # same as `set :option, false`
  disable :option

  # you can also have dynamic settings with blocks
  set(:css_dir) { File.join(views, 'css') }
end
~~~~

只当环境 (`RACK_ENV` environment 变量) 被设定为 `:production`的时候运行：

~~~~ruby
configure :production do
  ...
end
~~~~

当环境被设定为 `:production` 或者 `:test`的时候运行：

~~~~ruby
configure :production, :test do
  ...
end
~~~~

你可以使用 `settings` 获得这些配置:

~~~~ruby
configure do
  set :foo, 'bar'
end

get '/' do
  settings.foo? # => true
  settings.foo  # => 'bar'
  ...
end
~~~~

### 配置攻击保护

Sinatra 使用
[Rack::Protection](https://github.com/sinatra/rack-protection#readme)
来为你的应用防范常见的，机会主义的攻击。你可以很容易地禁用这一行为
（这会使你的应用暴露出大量常见的脆弱点）：

```ruby
disable :protection
```

为跳过一个防御层，设置 `protection` 为一个选项哈希表：

```ruby
set :protection, :except => :path_traversal
```

为禁用一系列保护，你也可以提交一个数组：

```ruby
set :protection, :except => [:path_traversal, :session_hijacking]
```

默认情况下，Sinatra 只会在 `:sessions` 被启用时设置基于 session 的保护。
但有时你希望自己设置 session. 在这种情况下，
你可以通过传递 `:session` 选项设置基于 session 的保护：

```ruby
use Rack::Session::Pool
set :protection, :session => true
```

### 可选的设置

<dl>
  <dt>absolute_redirects</dt>
  <dd>
    如果被禁用，Sinatra会允许使用相对路径重定向， 但是，Sinatra就不再遵守
    RFC 2616标准 (HTTP 1.1), 该标准只允许绝对路径重定向。
  </dd>
  <dd>
    如果你的应用运行在一个未恰当设置的反向代理之后，
    你需要启用这个选项。注意 <tt>url</tt> 辅助方法 仍然会生成绝对 URL，除非你传入
    <tt>false</tt> 作为第二参数。
  </dd>
  <dd>默认禁用。</dd>

  <dt>add_charset</dt>
  <dd>
    设定 <tt>content_type</tt> 辅助方法会自动加上字符集信息的多媒体类型。
    你应该添加而不是覆盖这个选项:
    <tt>settings.add_charset << "application/foobar"</tt>
  </dd>

  <dt>app_file</dt>
  <dd>
    主应用文件，用来检测项目的根路径， views和public文件夹和内联模板。
  </dd>

  <dt>bind</dt>
  <dd>绑定的IP 地址 (默认: <tt>0.0.0.0</tt> <em>或</em>
  <tt>localhost</tt>, 如果 `environment` 设置为 development)。
  仅对于内置的服务器有用。</dd>

  <dt>default_encoding</dt>
  <dd>默认编码 (默认为 <tt>"utf-8"</tt>)。</dd>

  <dt>dump_errors</dt>
  <dd>在log中显示错误。</dd>

  <dt>environment</dt>
  <dd>
    当前环境，默认是 <tt>ENV['RACK_ENV']</tt>， 或者 <tt>"development"</tt> 如果不可用。
  </dd>

  <dt>logging</dt>
  <dd>使用logger</dd>

  <dt>lock</dt>
  <dd>
    对每一个请求放置一个锁， 只使用进程并发处理请求。
  </dd>
  <dd>如果你的应用不是线程安全则需启动。 默认禁用。</dd>

  <dt>method_override</dt>
  <dd>
    使用 <tt>_method</tt> 魔法以允许在旧的浏览器中在表单中使用 put/delete 方法
  </dd>

  <dt>port</dt>
  <dd>监听的端口号。只对内置服务器有用。</dd>

  <dt>prefixed_redirects</dt>
  <dd>
    是否添加 <tt>request.script_name</tt> 到
    重定向请求，如果没有设定绝对路径。那样的话 <tt>redirect '/foo'</tt> 会和
    <tt>redirect to('/foo')</tt>起相同作用。默认禁用。
  </dd>
  
  <dt>protection</dt>
  <dd>是否启用网络攻击保护。参见上面的保护一节。</dd>

  <dt>public_dir</dt>
  <dd><tt>public_folder</tt>的别名。见下。</dd>
  
  <dt>public_folder</dt>
  <dd>
    public文件夹的位置。只有当静态文件服务启用时有效。（见下面的 <tt>static</tt>
    设置）。如果未设置，则从 <tt>app_file</tt> 设置推导。
  </dd>

  <dt>reload_templates</dt>
  <dd>
    是否每个请求都重新载入模板。 在 development mode 中启用。
  </dd>

  <dt>root</dt>
  <dd>
    项目的根目录。如果未设置，则从 <tt>app_file</tt> 设置推导。
  </dd>

  <dt>raise_errors</dt>
  <dd>
    抛出异常（应用会停下）。当 <tt>environment</tt> 被设为 <tt>"test"</tt>
    时默认启用，否则禁用。
  </dd>

  <dt>run</dt>
  <dd>
     如果启用，Sinatra会开启web服务器。 如果使用rackup或其他方式则不要启用。
  </dd>

  <dt>running</dt>
  <dd>
    内置的服务器在运行吗？ 不要修改这个设置！
  </dd>

  <dt>server</dt>
  <dd>
    服务器，或用于内置服务器的列表。顺序表明了优先级,
    默认值依赖 Ruby 实现。
  </dd>

  <dt>sessions</dt>
  <dd>
    使用 <tt>Rack::Session::Cookie</tt> 开启基于cookie的sesson。
    参见 ’使用 session‘ 一节以获得更多信息。
  </dd>

  <dt>show_exceptions</dt>
  <dd>
    当异常发生时，在浏览器中显示一个stack trace。
    当 <tt>environment</tt> 被设为 <tt>"development"</tt> 时，默认启用，
    否则禁用。
  </dd>
  <dd>
    也可被设为 <tt>:after_handler</tt> 来在在浏览器中显示 stack trace 前触发应用指定的错误处理。
  </dd>

  <dt>static</dt>
  <dd>Sinatra是否处理静态文件。</dd>
  <dd>当服务器能够处理则禁用。</dd> 
  <dd>禁用会增强性能。</dd>
  <dd>
    在经典风格下默认开启，对模块化应用禁用。
  </dd>

  <dt>static_cache_control</dt>
  <dd>
    当 Sinatra 服务静态文件时，设置这个来为响应添加 <tt>Cache-Control</tt> 消息头。
    使用 <tt>cache_control</tt> 辅助函数。默认禁用。
  </dd>
  <dd>
    当设置多个值时，使用明确的数组：
    <tt>set :static_cache_control, [:public, :max_age => 300]</tt>
  </dd>

  <dt>threaded</dt>
  <dd>
    如果设为 <tt>true</tt>, 将让 Thin 使用 <tt>EventMachine.defer</tt> 处理请求。
  </dd>

  <dt>traps</dt>
  <dd>Sinatra 是否应该处理系统信号。</dd>


  <dt>views</dt>
  <dd>
    views 文件夹。如果未设置，则从 <tt>app_file</tt> 设置推导。
  </dd>
  
  <dt>x_cascade</dt>
  <dd>
    当没有路由匹配时是否设置 X-Cascade 消息头。
    默认为 <tt>true</tt>.
  </dd>
</dl>

## 环境

有三种预定义的 `environments`: `"development"`, `"production"` 和
`"test"`. 环境可通过 `RACK_ENV` 环境变量设置。
默认值是 `"development"`. 在 `"development"`
环境中所有模板在请求间会被重新加载，并且特殊的 `not_found` 和 `error`
处理器会在浏览器中显示 stack traces. 在 `"production"` 和
`"test"` 环境，模板默认会被缓存。

为以不同的环境运行，请设置 `RACK_ENV` 环境变量：

```shell
RACK_ENV=production ruby my_app.rb
```

你可以使用预定义的 `development?`, `test?` 和 `production?` 方法来检查当前环境设置：

```ruby
get '/' do
  if settings.development?
    "development!"
  else
    "not development!"
  end
end
```

## 错误处理

错误处理在与路由和前置过滤器相同的上下文中运行，
这意味着你可以使用许多好东西，比如 `haml`, `erb`, `halt`，等等。

### 未找到

当一个 `Sinatra::NotFound` 异常被抛出的时候，
或者响应状态码是404，`not_found` 处理器会被调用：

~~~~ruby
not_found do
  'This is nowhere to be found'
end
~~~~

### 错误

`error` 处理器，在任何路由代码块或者过滤器抛出异常的时候会被调用。
但注意在开发环境中它只会在你设置 `:show_exceptions` 选项为
`:after_handler` 时运行：

```ruby
set :show_exceptions, :after_handler
```

异常对象可以通过 `sinatra.error` Rack 变量获得：

~~~~ruby
error do
  'Sorry there was a nasty error - ' + env['sinatra.error'].message
end
~~~~

自定义错误：

~~~~ruby
error MyCustomError do
  'So what happened was...' + env['sinatra.error'].message
end
~~~~

那么，当这个发生的时候：

~~~~ruby
get '/' do
  raise MyCustomError, 'something bad'
end
~~~~

你会得到：

```
So what happened was... something bad
```

另一种替代方法是，为一个状态码安装错误处理器：

~~~~ruby
error 403 do
  'Access forbidden'
end

get '/secret' do
  403
end
~~~~

或者一个范围：

~~~~ruby
error 400..510 do
  'Boom'
end
~~~~

在运行在development环境下时，Sinatra会安装特殊的 `not_found` 和 `error`
处理器以在浏览器中显示好看的 stack traces 和附加调试信息。

## Rack 中间件

Sinatra 依靠 [Rack](http://rack.github.io/), 一个面向Ruby
web框架的最小标准接口。
Rack的一个最有趣的面向应用开发者的能力是支持“中间件”——坐落在服务器和你的应用之间，
监视 并/或 操作HTTP请求/响应以提供多样类型的常用功能。

Sinatra 让建立Rack中间件管道异常简单， 通过顶层的 `use` 方法：

~~~~ruby
require 'sinatra'
require 'my_custom_middleware'

use Rack::Lint
use MyCustomMiddleware

get '/hello' do
  'Hello World'
end
~~~~

`use` 的语义和在
[Rack::Builder](http://www.rubydoc.info/github/rack/rack/master/Rack/Builder)
DSL(在rack文件中最频繁使用)中定义的完全一样。例如，`use` 方法接受
多个/可变 参数，包括代码块：

~~~~ruby
use Rack::Auth::Basic do |username, password|
  username == 'admin' && password == 'secret'
end
~~~~

Rack中分布有多样的标准中间件，针对日志，
调试，URL路由，认证和session处理。 Sinatra会根据配置自动使用这里面的大部分组件，
所以你一般不需要显示地 `use` 他们。

你可以在
[rack](https://github.com/rack/rack/tree/master/lib/rack),
[rack-contrib](https://github.com/rack/rack-contrib#readm),
或 [Rack wiki](https://github.com/rack/rack/wiki/List-of-Middleware)
找到有用的中间件。

## 测试

Sinatra的测试可以使用任何基于Rack的测试程序库或者框架来编写。
[Rack::Test](http://www.rubydoc.info/github/brynary/rack-test/master/frames)
是推荐候选：

~~~~ruby
require 'my_sinatra_app'
require 'minitest/autorun'
require 'rack/test'

class MyAppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_my_default
    get '/'
    assert_equal 'Hello World!', last_response.body
  end

  def test_with_params
    get '/meet', :name => 'Frank'
    assert_equal 'Hello Frank!', last_response.body
  end

  def test_with_rack_env
    get '/', {}, 'HTTP_USER_AGENT' => 'Songbird'
    assert_equal "You're using Songbird!", last_response.body
  end
end
~~~~

注意： 如果你以模块化风格使用 Sinatra, 用你应用的类名替换上面的
`Sinatra::Application`.

## Sinatra::Base - 中间件，程序库和模块化应用

把你的应用定义在顶层，对于微型应用这会工作得很好，
但是在构建可复用的组件时候会带来客观的不利， 比如构建Rack中间件，Rails
metal，带有服务器组件的简单程序库，
或者甚至是Sinatra扩展。顶层的DSL假定了一个微型应用风格的配置
(例如, 单一的应用文件， `./public` 和`./views` 目录，日志，异常细节页面，等等）。
这时应该让 `Sinatra::Base` 走到台前了：

~~~~ruby
require 'sinatra/base'

class MyApp < Sinatra::Base
  set :sessions, true
  set :foo, 'bar'

  get '/' do
    'Hello world!'
  end
end
~~~~

`Sinatra::Base` 子类可用的方法实际上就是通过顶层 DSL 可用的方法。
大部分顶层应用可以通过两个改变转换成 `Sinatra::Base` 组件：

-   你的文件应当引入 `sinatra/base` 而不是 `sinatra`;
    否则，所有的Sinatra的 DSL 方法将会被引进到 主命名空间。

-   把你的应用的路由，错误处理，过滤器和选项放在
    一个Sinatra::Base的子类中。

`Sinatra::Base` 是一张白纸。大部分的选项默认是禁用的，
包含内置的服务器。参见
[选项和配置](http://www.sinatrarb.com/configuration.html)
查看可用选项的具体细节和他们的行为。
如果你想要和你在顶层定义的应用（也称为传统的方式）更为相似的行为，
你可以子类化 `Sinatra::Application`.

```ruby
require 'sinatra/base'

class MyApp < Sinatra::Application
  get '/' do
    'Hello world!'
  end
end
```

### 模块化 vs. 传统的方式

与通常的认识相反，传统的方式没有任何错误。
如果它适合你的应用，你不需要转换到模块化的应用。

和模块化方式相比传统方式的主要缺点是：
你对每个Ruby进程只能定义一个Sinatra应用，如果你需要更多，切换到模块化方式。
没有任何原因阻止你混合模块化和传统方式。

如果从一种转换到另一种，你需要注意默认 settings 中的一些微小的不同:

<table>
  <tr>
    <th>Setting</th>
    <th>Classic</th>
    <th>Modular</th>
    <th>Modular</th>
  </tr>

  <tr>
    <td>app_file</td>
    <td>加载 sinatra 的文件</td>
    <td>子类化 Sinatra::Base 的文件</td>
    <td>子类化 Sinatra::Application 的文件</td>
  </tr>

  <tr>
    <td>run</td>
    <td>$0 == app_file</td>
    <td>false</td>
    <td>false</td>
  </tr>

  <tr>
    <td>logging</td>
    <td>true</td>
    <td>false</td>
    <td>true</td>
  </tr>

  <tr>
    <td>method_override</td>
    <td>true</td>
    <td>false</td>
    <td>true</td>
  </tr>

  <tr>
    <td>inline_templates</td>
    <td>true</td>
    <td>false</td>
    <td>true</td>
  </tr>

  <tr>
    <td>static</td>
    <td>true</td>
    <td>false</td>
    <td>true</td>
  </tr>
</table>

### 运行一个模块化应用

有两种方式运行一个模块化应用，使用 `run!`来运行:

~~~~ruby
# my_app.rb
require 'sinatra/base'

class MyApp < Sinatra::Base
  # ... app code here ...

  # start the server if ruby file executed directly
  run! if app_file == $0
end
~~~~

运行:

```shell
ruby my_app.rb
```

或者使用一个 `config.ru`，允许你使用任何Rack处理器:

~~~~ruby
# config.ru (run with rackup)
require './my_app'
run MyApp
~~~~

运行:

```shell
rackup -p 4567
```

### 使用config.ru运行传统方式的应用

编写你的应用:

~~~~ruby
# app.rb
require 'sinatra'

get '/' do
  'Hello world!'
end
~~~~

加入相应的 `config.ru`:

~~~~ruby
require './app'
run Sinatra::Application
~~~~

### 什么时候用 config.ru?

以下情况你可能需要使用 `config.ru`:

-   你要使用不同的 Rack 处理器部署 (Passenger, Unicorn, Heroku, …).

-   你想使用多于一个的 `Sinatra::Base`的子类.

-   你只想把Sinatra当作中间件使用，而不是端点。

**你并不需要切换到`config.ru`仅仅因为你切换到模块化方式，
你同样不需要切换到模块化方式， 仅仅因为要运行 `config.ru`.**

### 把Sinatra当成中间件来使用

不仅Sinatra有能力使用其他的Rack中间件，任何Sinatra
应用程序都可以反过来自身被当作中间件，被加在任何Rack端点前面。
这个端点可以是任何Sinatra应用，或者任何基于Rack的应用程序
(Rails/Ramaze/Camping/…)：

~~~~ruby
require 'sinatra/base'

class LoginScreen < Sinatra::Base
  enable :sessions

  get('/login') { haml :login }

  post('/login') do
    if params['name'] = 'admin' and params['password'] = 'admin'
      session['user_name'] = params['name']
    else
      redirect '/login'
    end
  end
end

class MyApp < Sinatra::Base
  # 在前置过滤器前运行中间件
  use LoginScreen

  before do
    unless session['user_name']
      halt "Access denied, please <a href='/login'>login</a>."
    end
  end

  get('/') { "Hello #{session['user_name']}." }
end
~~~~

### 动态应用程序创建

有时你向在运行时创建新的应用而不用将其赋值给一个常量。
你可以通过 `Sinatra.new` 做到这样：

```ruby
require 'sinatra/base'
my_app = Sinatra.new { get('/') { "hi" } }
my_app.run!
```

它接受要继承的应用作为可选参数：

```ruby
# config.ru (run with rackup)
require 'sinatra/base'

controller = Sinatra.new do
  enable :logging
  helpers MyHelpers
end

map('/a') do
  run Sinatra.new(controller) { get('/') { 'a' } }
end

map('/b') do
  run Sinatra.new(controller) { get('/') { 'b' } }
end
```

对测试 Sinatra 扩展或在你自己的库中使用 Sinatra 十分有用。

这也使得使用 Sinatra 作为中间件极其容易：

```ruby
require 'sinatra/base'

use Sinatra do
  get('/') { ... }
end

run RailsProject::Application
```

## 变量域和绑定

当前所在的变量域决定了哪些方法和变量是可用的。

### 应用/类 变量域

每个Sinatra应用对应 `Sinatra::Base` 的一个子类。
如果你在使用顶层DSL(`require 'sinatra'`)，那么这个类就是
`Sinatra::Application` ，或者这个类就是你显式创建的子类。
在类层面，你具有类似于 `get` 或者 `before`的方法，但是你不能访问
`request` 对象或者 `session`, 因为对于所有的请求，
只有单一的应用类。

通过 `set` 创建的选项是类层面的方法：

~~~~ruby
class MyApp < Sinatra::Base
  # 嘿，我在应用变量域！
  set :foo, 42
  foo # => 42

  get '/foo' do
    # 嘿，我不再处于应用变量域了！
  end
end
~~~~

在下列情况下你将拥有应用变量域的绑定：

* 在应用类中
* 在扩展中定义的方法
* 传递给 `helpers` 的代码块
* 用作 `set`值的过程/代码块
* 传递给 `Sinatra.new` 的代码块

你可以访问变量域对象（就是应用类）就像这样：

* 通过传递给配置代码块的对象 (`configure { |c| ... }`)
* 在请求变量域中使用 `settings`

### 请求/实例 变量域

对于每个进入的请求，一个新的应用类的实例会被创建，
所有的处理器代码块在该变量域被运行。在这个变量域中，你可以访问
`request` 和 `session` 对象，或者调用填充方法比如 `erb` 或者
`haml`。你可以在请求变量域当中通过 `settings` 辅助方法
访问应用变量域：

~~~~ruby
class MyApp < Sinatra::Base
  # 嘿，我在应用变量域!
  get '/define_route/:name' do
    # 针对 '/define_route/:name' 的请求变量域
    @value = 42

    settings.get("/#{params['name']}") do
      # 针对 "/#{params['name']}" 的请求变量域
      @value # => nil (并不是相同的请求)
    end

    "Route defined!"
  end
end
~~~~

在以下情况将获得请求变量域：

* get, head, post, put, delete, options, patch, link 和 unlink 代码块
* 前置/后置 过滤器
* 辅助方法
* 模板/视图

### 代理变量域

代理变量域只是把方法转送到类变量域。可是，
他并非表现得100%类似于类变量域, 因为你并不能获得类的绑定:
只有显式地标记为供代理使用的方法才是可用的，
而且你不能和类变量域共享变量/状态。(解释：你有了一个不同的 `self`)。
你可以显式地增加方法代理，通过调用
`Sinatra::Delegator.delegate :method_name`。

在以下情况将获得代理变量域：

* 顶层的绑定，如果你做过 `require "sinatra"`
* 在扩展了 `Sinatra::Delegator` mixin的对象

自己在这里看一下代码: [Sinatra::Delegator
mixin](https://github.com/sinatra/sinatra/blob/ca06364/lib/sinatra/base.rb#L1609-1633)
已经
[扩展了 main 对象](https://github.com/sinatra/sinatra/blob/ca06364/lib/sinatra/main.rb#L28-30)
。

## 命令行

Sinatra 应用可以被直接运行：

```shell
ruby myapp.rb [-h] [-x] [-e ENVIRONMENT] [-p PORT] [-o HOST] [-s HANDLER]
```

选项是：

    -h # help
    -p # 设定端口 (默认是 4567)
    -o # 设定主机名 (默认是 0.0.0.0)
    -e # 设定环境 (默认是 development)
    -s # 限定 rack 服务器/处理器 (默认是 thin)
    -x # 打开互斥锁 (默认是 off)

### 多线程

_从 Konstantin 的[这个 StackOverflow 回答][so-answer]转述_

Sinatra 不强求任何并发模型，把这留给下面的 Rack 处理器 (server) 像 Thin, Puma 或 WEBrick.
Sinatra 本身是线程安全的，所以如果 Rack 处理器使用基于线程的并发模型也不会有任何问题。
这意味着启动服务器时，你应该为特定 Rack 处理器指定正确的调用方法。
下面的例子是演示如何启动一个多线程的 Thin 服务器：

```ruby
# app.rb

require 'sinatra/base'

class App < Sinatra::Base
  get '/' do
    "Hello, World"
  end
end

App.run!

```

启动服务器的命令是：

```shell
thin --threaded start
```


[so-answer]: http://stackoverflow.com/questions/6278817/is-sinatra-multi-threaded/6282999#6282999)

## 必要条件

下面的Ruby版本是官方支持的:
<dl>
    <dt>Ruby 1.8.7</dt>
    <dd>
        1.8.7 被完全支持，但是，如果没有特别原因， 我们推荐你升级
        或者切换到 JRuby 或者 Rubinius.
        1.8.7 的支持在 Sinatra 2.0 前不会被放弃。Ruby 1.8.6 不再被支持。
    </dd>

    <dt>Ruby 1.9.2</dt>
    <dd>
        1.9.2 被完全支持。不要使用1.9.2p0, 它被已知会产生 segmentation faults.
        官方支持将至少持续到 Sinatra 1.5 发布。
    </dd>
    <dt>Ruby 1.9.3</dt>
    <dd>
      1.9.3 被完全支持并被推荐。请注意从更早的版本转换到 1.9.3 会使所有 session 不合法。
      1.9.3 会被支持到 Sinatra 2.0 发布。
    </dd>

    <dt>Ruby 2.x</dt>
    <dd>
      2.x 被完全支持并被推荐。目前没有计划取消它的官方支持。
    </dd>

    <dt>Rubinius</dt>
    <dd>
        Rubinius 被官方支持 (Rubinius >= 2.x). 推荐 <tt>gem install puma</tt>.
    </dd>

    <dt>JRuby</dt>
    <dd>
       JRuby 的最新稳定发布被官方支持。不推荐在 JRuby 用 C 扩展。
       推荐 <tt>gem install trinidad</tt>.
    </dd>
</dl>

我们也会时刻关注新的Ruby版本。

下面的 Ruby 实现没有被官方支持， 但是已知可以运行 Sinatra:

* JRuby 和 Rubinius 老版本
* Ruby Enterprise Edition
* MacRuby, Maglev, IronRuby
* Ruby 1.9.0 and 1.9.1 (但我们确实建议不要用这些）

不被官方支持的意思是，如果只在不被支持的平台上有运行错误，
我们假定不是我们的问题，而是平台的问题。

我们也对 ruby-head（未来的 MRI 发布）运行 CI, 但我们不能做任何保证，
因为它一直在变化。期待将来的 2.x 版本被完全支持。

Sinatra应该会运行在任何支持上述Ruby实现的操作系统。

如果你运行 MacRuby, 你应该 `gem install control_tower`.

Sinatra 目前不能在 Cardinal, SmallRuby, BlueRuby
或 1.8.7 之前的 Ruby 版本运行。

## 紧追前沿

如果你喜欢使用 Sinatra 的最新鲜的代码，请放心的使用 master
分支来运行你的程序，它会非常的稳定。

    cd myapp
    git clone git://github.com/sinatra/sinatra.git
    ruby -Isinatra/lib myapp.rb

我们也会不定期的发布预发布gems，所以你也可以运行

 ```shell
 gem install sinatra --pre
 ```

来获得最新的特性。

### 通过Bundler

如果你想使用最新的Sinatra运行你的应用，通过
[Bundler](http://bundler.io) 是推荐的方式。

首先，安装bundler，如果你还没有安装:

```shell
gem install bundler
```

然后，在你的项目目录下，创建一个 `Gemfile`:

```ruby
source 'https://rubygems.org'
gem 'sinatra', :github => "sinatra/sinatra"

# 其他的依赖关系
gem 'haml'                    # 举例，如果你想用haml
gem 'activerecord', '~> 3.0'  # 也许你还需要 ActiveRecord 3.x
```

请注意在这里你需要列出你的应用的所有依赖关系。 Sinatra的直接依赖关系
(Rack and Tilt) 将会，自动被Bundler获取和添加。

现在你可以像这样运行你的应用:

```shell
bundle exec ruby myapp.rb
```

### 使用自己的

创建一个本地克隆并通过 `sinatra/lib` 目录运行你的应用， 通过
`$LOAD_PATH`:

```shell
cd myapp
git clone git://github.com/sinatra/sinatra.git
ruby -I sinatra/lib myapp.rb
```

在未来更新 Sinatra 源代码:

```shell
cd myapp/sinatra
git pull
```

### 全局安装

你可以自行编译 gem :

```shell
git clone git://github.com/sinatra/sinatra.git
cd sinatra
rake sinatra.gemspec
rake install
```

如果你以root身份安装 gems，最后一步应该是：

```shell
sudo rake install
```

## 版本号

Sinatra 遵循 [Semantic Versioning](http://semver.org/)，SemVer 和
SemVerTag 兼有。

## 更多

-   [项目主页（英文）](http://www.sinatrarb.com/) - 更多的文档，
    新闻，和其他资源的链接。

-   [贡献](http://www.sinatrarb.com/contributing) - 找到了一个bug？
    需要帮助？有了一个 patch?

-   [问题追踪](https://github.com/sinatra/sinatra/issues)

-   [Twitter](https://twitter.com/sinatra)

-   [邮件列表](http://groups.google.com/group/sinatrarb/topics)

-   IRC: [#sinatra](irc://chat.freenode.net/#sinatra) on
    [freenode.net](http://freenode.net)

-   [Sinatra & Friends](https://sinatrarb.slack.com)位于 Slack 上，
    查看[这里](https://sinatra-slack.herokuapp.com/)取得邀请

-   [Sinatra宝典](https://github.com/sinatra/sinatra-book/) Cookbook教程

-   [Sinatra使用技巧](http://recipes.sinatrarb.com/) 网友贡献的实用技巧

-   [最新版本](http://www.rubydoc.info/gems/sinatra)的API文档和位于
[http://www.rubydoc.info](http://www.rubydoc.info) 的
[当前HEAD](http://www.rubydoc.info/github/sinatra/sinatra)的API文档

-   [CI服务器](https://travis-ci.org/sinatra/sinatra)
