# Sinatra

*주의: 이 문서는 영문판의 번역본이며 최신판 문서와 다를 수 있음.*

Sinatra는 최소한의 노력으로 루비 기반 웹 애플리케이션을 신속하게 만들 수 있게 해 주는 [DSL](http://en.wikipedia.org/wiki/Domain-specific_language)이다:

```ruby
# myapp.rb
require 'sinatra'

get '/' do
  'Hello world!'
end
```

다음과 같이 젬을 설치하고 실행한다:

```ruby
gem install sinatra
ruby myapp.rb
```

확인: http://localhost:4567

`gem install thin`도 함께 실행하기를 권장하며, 그럴 경우 Sinatra는 thin을 부른다.

## 라우터(Routes)

Sinatra에서, 라우터(route)는 URL-매칭 패턴과 쌍을 이루는 HTTP 메서드다.
각각의 라우터는 블록과 연결된다:

```ruby
get '/' do
  .. 무언가 보여주기(show) ..
end

post '/' do
  .. 무언가 만들기(create) ..
end

put '/' do
  .. 무언가 대체하기(replace) ..
end

patch '/' do
  .. 무언가 수정하기(modify) ..
end

delete '/' do
  .. 무언가 없애기(annihilate) ..
end

options '/' do
  .. 무언가 주기(appease) ..
end
```

라우터는 정의된 순서에 따라 매치되며 매칭된 첫 번째 라우터가 호출된다.

라우터 패턴에는 이름을 가진 매개변수가 포함될 수있으며, `params` 해시로 접근할 수 있다:

```ruby
get '/hello/:name' do
  # "GET /hello/foo" 및 "GET /hello/bar"와 매치
  # params[:name]은 'foo' 또는 'bar'
  "Hello #{params[:name]}!"
end
```

또한 블록 매개변수를 통하여도 이름을 가진 매개변수에 접근할 수 있다:

```ruby
get '/hello/:name' do |n|
  "Hello #{n}!"
end
```

라우터 패턴에는 스플랫(splat, 또는 와일드카드)도 포함될 수 있으며, 이럴 경우 `params[:splat]` 배열로 접근할 수 있다:

```ruby
get '/say/*/to/*' do
  # /say/hello/to/world와 매치
  params[:splat] # => ["hello", "world"]
end

get '/download/*.*' do
  # /download/path/to/file.xml과 매치
  params[:splat] # => ["path/to/file", "xml"]
end
```

또는 블록 매개변수도 가능하다:

```ruby
get '/download/*.*' do |path, ext|
  [path, ext] # => ["path/to/file", "xml"]
end
```

정규표현식을 이용한 라우터 매칭:

```ruby
get %r{/hello/([\w]+)} do
  "Hello, #{params[:captures].first}!"
end
```

또는 블록 매개변수로도 가능:

```ruby
get %r{/hello/([\w]+)} do |c|
  "Hello, #{c}!"
end
```

라우터 패턴에는 선택적인(optional) 매개변수도 올 수 있다:

```ruby
get '/posts.?:format?' do
  # "GET /posts" 및 "GET /posts.json", "GET /posts.xml" 와 같은 어떤 확장자와도 매칭
end
```

한편, 경로 탐색 공격 방지(path traversal attack protection, 아래 참조)를 비활성화시키지 않았다면, 
요청 경로는 라우터와 매칭되기 이전에 수정될 수 있다.

### 조건(Conditions)

라우터는 예를 들면 사용자 에이전트(user agent)와 같은 다양한 매칭 조건을 포함할 수 있다:

```ruby
get '/foo', :agent => /Songbird (\d\.\d)[\d\/]*?/ do
  "Songbird 버전 #{params[:agent][0]}을 사용하는군요!"
end

get '/foo' do
  # songbird 브라우저가 아닌 경우 매치
end
```

그 밖에 다른 조건으로는 `host_name`과 `provides`가 있다:

```ruby
get '/', :host_name => /^admin\./ do
  "Admin Area, Access denied!"
end

get '/', :provides => 'html' do
  haml :index
end

get '/', :provides => ['rss', 'atom', 'xml'] do
  builder :feed
end
```

여러분만의 조건도 쉽게 정의할 수 있다:

```ruby
set(:probability) { |value| condition { rand <= value } }

get '/win_a_car', :probability => 0.1 do
  "내가 졌소!"
end

get '/win_a_car' do
  "미안해서 어쩌나."
end
```

여러 값을 받는 조건에는 스플랫(splat)을 사용하자:

```ruby
set(:auth) do |*roles|   # <- 이게 스플랫
  condition do
    unless logged_in? && roles.any? {|role| current_user.in_role? role }
      redirect "/login/", 303
    end
  end
end

get "/my/account/", :auth => [:user, :admin] do
  "내 계정 정보"
end

get "/only/admin/", :auth => :admin do
  "관리자 외 접근불가!"
end
```

### 반환값(Return Values)

라우터 블록의 반환값은 HTTP 클라이언트로 전달되는 응답 본문을 결정하거나, 또는 Rack 스택에서 다음 번 미들웨어를 결정한다.
대부분의 경우, 이 반환값은 위의 예제에서 보듯 문자열이지만, 다른 값도 가능하다.

유효한 Rack 응답, Rack 본문 객체 또는 HTTP 상태 코드가 되는 어떠한 객체라도 반환할 수 있다:

* 세 요소를 가진 배열: `[상태 (Fixnum), 헤더 (Hash), 응답 본문 (#each에 반응)]`
* 두 요소를 가진 배열: `[상태 (Fixnum), 응답 본문 (#each에 반응)]`
* `#each`에 반응하고 주어진 블록으로 문자열만을 전달하는 객체
* 상태 코드를 의미하는 Fixnum

이에 따라 우리는, 예를 들면, 스트리밍(streaming) 예제를 쉽게 구현할 수 있다:

```ruby
class Stream
  def each
100.times { |i| yield "#{i}\n" }
  end
end

get('/') { Stream.new }
```

이런 번거로움을 줄이기 위해 `stream` 헬퍼 메서드(아래 참조)를 사용하여 스트리밍 로직을 라우터 속에 둘 수도 있다.

### 커스텀 라우터 매처(Custom Route Matchers)

위에서 보듯, Sinatra에는 문자열 패턴 및 정규표현식을 이용한 라우터 매칭 지원이 내장되어 있다.
그렇지만, 그게 끝이 아니다. 여러분 만의 매처(matcher)도 쉽게 정의할 수 있다:

```ruby
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
```

사실 위의 예제는 조금 과하게 작성된 면이 있다. 다음과 같이 표현할 수도 있다:

```ruby
get // do
  pass if request.path_info == "/index"
  # ...
end
```

또는 네거티브 룩어헤드(negative look ahead)를 사용할 수도 있다:

```ruby
get %r{^(?!/index$)} do
  # ...
end
```

## 정적 파일(Static Files)

정적 파일들은 `./public`에서 제공된다.
위치를 다른 곳으로 변경하려면 `:public_folder` 옵션을 사용하면 된다:

```ruby
set :public_folder, File.dirname(__FILE__) + '/static'
```

이 때 public 디렉터리명은 URL에 포함되지 않는다는 점에 유의.
`./public/css/style.css` 파일은 `http://example.com/css/style.css` 로 접근할 수 있다.

`Cache-Control` 헤더 정보를 추가하려면 `:static_cache_control` 설정(아래 참조)을 사용하면 된다.

## 뷰 / 템플릿(Views / Templates)

각 템플릿 언어는 그들만의 고유한 렌더링 메서드를 통해 표출된다.
이들 메서드는 단순히 문자열을 반환한다.

```ruby
get '/' do
  erb :index
end
```

이 메서드는 `views/index.erb`를 렌더한다.

템플릿 이름 대신 템플릿의 내용을 직접 전달할 수도 있다:

```ruby
get '/' do
  code = "<%= Time.now %>"
  erb code
end
```

템플릿은 두 번째 인자로 옵션값의 해시를 받는다:

```ruby
get '/' do
  erb :index, :layout => :post
end
```

이렇게 하면 `views/post.erb` 속에 내장된 `views/index.erb`를 렌더한다.
(기본값은 `views/layout.erb`이며, 이 파일이 존재할 경우에만 먹는다).

Sinatra가 이해하지 못하는 모든 옵션값들은 템플릿 엔진으로 전달될 것이다:

```ruby
get '/' do
  haml :index, :format => :html5
end
```

옵션값은 템플릿 언어별로 일반적으로 설정할 수도 있다:

```ruby
set :haml, :format => :html5

get '/' do
  haml :index
end
```

render 메서드에서 전달된 옵션값들은 `set`을 통해 설정한 옵션값을 덮어 쓴다.

가능한 옵션값들:

<dl>
  <dt>locals</dt>
  <dd>문서로 전달되는 local 목록. 파셜과 함께 사용하기 좋음.
예제: <tt>erb "<%= foo %>", :locals => {:foo => "bar"}</tt>
  </dd>

  <dt>default_encoding</dt>
  <dd>불확실한 경우에 사용할 문자열 인코딩. 기본값은 <tt>settings.default_encoding</tt>.</dd>

  <dt>views</dt>
  <dd>템플릿을 로드할 뷰 폴더. 기본값은 <tt>settings.views</tt>.</dd>

  <dt>layout</dt>
  <dd>레이아웃을 사용할지 여부 (<tt>true</tt> 또는 <tt>false</tt>), 만약 이 값이 심볼일 경우, 
사용할 템플릿을 지정. 예제: <tt>erb :index, :layout => !request.xhr?</tt>
  </dd>

  <dt>content_type</dt>
  <dd>템플릿이 생성하는 Content-Type, 기본값은 템플릿 언어에 의존.</dd>

  <dt>scope</dt>
  <dd>템플릿을 렌더링하는 범위. 기본값은 어플리케이션 인스턴스.
만약 이 값을 변경하면, 인스턴스 변수와 헬퍼 메서드들을 사용할 수 없게 됨.</dd>

  <dt>layout_engine</dt>
  <dd>
레이아웃 렌더링에 사용할 템플릿 엔진. 레이아웃을 지원하지 않는 언어인 경우에 유용.
기본값은 템플릿에서 사용하는 엔진. 예제: <tt>set :rdoc, :layout_engine => :erb</tt>
  </dd>
</dl>


템플릿은 `./views` 아래에 놓이는 것으로 가정됨. 만약 뷰 디렉터리를 다른 곳으로 두려면:

```ruby
set :views, settings.root + '/templates'
```

꼭 알아야 할 중요한 점 한 가지는 템플릿은 언제나 심볼로 참조된다는 것이며,
템플릿이 하위 디렉터리에 위치한 경우라도 마찬가지임(그럴 경우에는 `:'subdir/template'`을 사용). 
반드시 심볼이어야 하는 이유는, 만약 그렇게 하지 않으면 렌더링 메서드가 전달된 문자열을 직접 렌더하려 할 것이기 때문임.

### 가능한 템플릿 언어들(Available Template Languages)

일부 언어는 여러 개의 구현이 있음. 어느 구현을 사용할지 저정하려면(그리고 스레드-안전thread-safe 모드로 하려면),
먼저 require 시키기만 하면 됨:

```ruby
require 'rdiscount' # or require 'bluecloth'
get('/') { markdown :index }
```

### Haml 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://haml.info/">haml</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.haml</tt></td>
  </tr>
  <tr>
<td>예</td>
<td><tt>haml :index, :format => :html5</tt></td>
  </tr>
</table>

### Erb 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://www.kuwata-lab.com/erubis/">erubis</a> 또는 erb (루비 속에 포함)</td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.erb</tt>, <tt>.rhtml</tt> 또는 <tt>.erubis</tt> (Erubis만 해당)</td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>erb :index</tt></td>
  </tr>
</table>

### Builder 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://builder.rubyforge.org/">builder</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.builder</tt></td>
  </tr>
  <tr>
<td>Example</td>
<td><tt>builder { |xml| xml.em "hi" }</tt></td>
  </tr>
</table>

인라인 템플릿으로 블록을 받음(예제 참조).

### Nokogiri 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://nokogiri.org/">nokogiri</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.nokogiri</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>nokogiri { |xml| xml.em "hi" }</tt></td>
  </tr>
</table>

인라인 템플릿으로 블록을 받음(예제 참조).

### Sass 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://sass-lang.com/">sass</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.sass</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>sass :stylesheet, :style => :expanded</tt></td>
  </tr>
</table>

### SCSS 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://sass-lang.com/">sass</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.scss</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>scss :stylesheet, :style => :expanded</tt></td>
  </tr>
</table>

### Less 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://www.lesscss.org/">less</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.less</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>less :stylesheet</tt></td>
  </tr>
</table>

### Liquid 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://www.liquidmarkup.org/">liquid</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.liquid</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>liquid :index, :locals => { :key => 'value' }</tt></td>
  </tr>
</table>

Liquid 템플릿에서는 루비 메서드(`yield` 제외)를 호출할 수 없기 때문에, 거의 대부분의 경우 locals를 전달해야 함.

### Markdown 템플릿

<table>
  <tr>
    <td>의존</td>
    <td>
      <a href="https://github.com/rtomayko/rdiscount">rdiscount</a>,
      <a href="https://github.com/vmg/redcarpet">redcarpet</a>,
      <a href="http://deveiate.org/projects/BlueCloth">bluecloth</a>,
      <a href="http://kramdown.rubyforge.org/">kramdown</a> *또는*
      <a href="http://maruku.rubyforge.org/">maruku</a>
    </td>
  </tr>
  <tr>
    <td>파일 확장</td>
    <td><tt>.markdown</tt>, <tt>.mkd</tt>,  <tt>.md</tt></td>
  </tr>
  <tr>
    <td>예제</td>
    <td><tt>markdown :index, :layout_engine => :erb</tt></td>
  </tr>
</table>

마크다운에서는 메서드 호출 뿐 아니라 locals 전달도 안됨. 
따라서 일반적으로는 다른 렌더링 엔진과 함께 사용하게 될 것임:

```ruby
erb :overview, :locals => { :text => markdown(:introduction) }
```

또한 다른 템플릿 속에서 `markdown` 메서드를 호출할 수도 있음:

```ruby
%h1 안녕 Haml!
%p= markdown(:greetings)
```

Markdown에서 루비를 호출할 수 없기 때문에, Markdown으로 작성된 레이아웃은 사용할 수 없음.
단, `:layout_engine` 옵션으로 템플릿의 레이아웃은 다른 렌더링 엔진을 사용하는 것은 가능.

### Textile 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://redcloth.org/">RedCloth</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.textile</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>textile :index, :layout_engine => :erb</tt></td>
  </tr>
</table>

Textile에서 메서드를 호출하거나 locals를 전달하는 것은 불가능함.
따라서 일반적으로 다른 렌더링 엔진과 함께 사용하게 될 것임:

```ruby
erb :overview, :locals => { :text => textile(:introduction) }
```

또한 다른 템플릿 속에서 `textile` 메서드를 호출할 수도 있음:

```ruby
%h1 안녕 Haml!
%p= textile(:greetings)
```

Textile에서 루비를 호출할 수 없기 때문에, Textile로 작성된 레이아웃은 사용할 수 없음.
단, `:layout_engine` 옵션으로 템플릿의 레이아웃은 다른 렌더링 엔진을 사용하는 것은 가능.

### RDoc 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://rdoc.rubyforge.org/">rdoc</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.rdoc</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>rdoc :README, :layout_engine => :erb</tt></td>
  </tr>
</table>

rdoc에서 메서드를 호출하거나 locals를 전달하는 것은 불가능함.
따라서 일반적으로 다른 렌더링 엔진과 함께 사용하게 될 것임:

```ruby
erb :overview, :locals => { :text => rdoc(:introduction) }
```

또한 다른 템플릿 속에서 `rdoc` 메서드를 호출할 수도 있음:

```ruby
%h1 Hello From Haml!
%p= rdoc(:greetings)
```

RDoc에서 루비를 호출할 수 없기 때문에, RDoc로 작성된 레이아웃은 사용할 수 없음.
단, `:layout_engine` 옵션으로 템플릿의 레이아웃은 다른 렌더링 엔진을 사용하는 것은 가능.
### Radius 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://radius.rubyforge.org/">radius</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.radius</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>radius :index, :locals => { :key => 'value' }</tt></td>
  </tr>
</table>

Radius 템플릿에서는 루비 메서드를 호출할 수 없기 때문에, 거의 대부분의 경우 locals로 전달하게 될 것임.

### Markaby 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://markaby.github.com/">markaby</a></td>
  </tr>
  <tr>
<td>파일확장</td>
<td><tt>.mab</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>markaby { h1 "Welcome!" }</tt></td>
  </tr>
</table>

인라인 템플릿으로 블록을 받을 수도 있음(예제 참조).

### RABL 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="https://github.com/nesquena/rabl">rabl</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.rabl</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>rabl :index</tt></td>
  </tr>
</table>

### Slim 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="http://slim-lang.com/">slim</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.slim</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>slim :index</tt></td>
  </tr>
</table>

### Creole 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="https://github.com/minad/creole">creole</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.creole</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>creole :wiki, :layout_engine => :erb</tt></td>
  </tr>
</table>

creole에서는 루비 메서드를 호출할 수 없고 locals도 전달할 수 없음.
따라서 일반적으로는 다른 렌더링 엔진과 함께 사용하게 될 것임.

```ruby
erb :overview, :locals => { :text => creole(:introduction) }
```

또한 다른 템플릿 속에서 `creole` 메서드를 호출할 수도 있음:

```ruby
%h1 Hello From Haml!
%p= creole(:greetings)
```

Creole에서 루비를 호출할 수 없기 때문에, Creole로 작성된 레이아웃은 사용할 수 없음.
단, `:layout_engine` 옵션으로 템플릿의 레이아웃은 다른 렌더링 엔진을 사용하는 것은 가능.

### CoffeeScript 템플릿

<table>
  <tr>
<td>의존성</td>
<td><a href="https://github.com/josh/ruby-coffee-script">coffee-script</a>
  와 <a href="https://github.com/sstephenson/execjs/blob/master/README.md#readme">자바스크립트 실행법</a>
</td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.coffee</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>coffee :index</tt></td>
  </tr>
</table>


### Yajl 템플릿

<table>
  <tr>
<td>의존</td>
<td><a href="https://github.com/brianmario/yajl-ruby">yajl-ruby</a></td>
  </tr>
  <tr>
<td>파일 확장자</td>
<td><tt>.yajl</tt></td>
  </tr>
  <tr>
<td>예제</td>
<td><tt>yajl :index, :locals => { :key => 'qux' }, :callback => 'present', :variable => 'resource' </tt></td>
  </tr>
</table>

The template source is evaluated as a Ruby string, and the resulting json variable is converted #to_json.
템플릿 소스는 루비 문자열로 평가(evaluate)되고, 결과인 json 변수는 #to_json으로 변환됨.

```ruby
json = { :foo => 'bar' }
json[:baz] = key
```

`:callback`과 `:variable` 옵션은 렌더된 객체를 꾸미는데(decorate) 사용할 수 있음.

```ruby
var resource = {"foo":"bar","baz":"qux"}; present(resource);
```

### 내장된(Embedded) 템플릿

```ruby
get '/' do
  haml '%div.title Hello World'
end
```

내장된 템플릿 문자열을 렌더함.

### 템플릿에서 변수에 접근하기

Templates are evaluated within the same context as route handlers. Instance
variables set in route handlers are directly accessible by templates:
템플릿은 라우터 핸들러와 같은 맥락(context)에서 평가된다.
라우터 핸들러에서 설정한 인스턴스 변수들은 템플릿에서 접근 가능하다: 

```ruby
get '/:id' do
  @foo = Foo.find(params[:id])
  haml '%h1= @foo.name'
end
```

또는, 명시적으로 로컬 변수의 해시를 지정: 

```ruby
get '/:id' do
  foo = Foo.find(params[:id])
  haml '%h1= bar.name', :locals => { :bar => foo }
end
```

This is typically used when rendering templates as partials from within
other templates.
이 방법은 통상적으로 템플릿을 다른 템플릿 속에서 파셜(partial)로 렌더링할 때 사용된다.

### 인라인 템플릿

템플릿은 소스 파일의 마지막에서 정의할 수도 있다:

```ruby
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
```

참고: require sinatra 시킨 소스 파일에 정의된 인라인 템플릿은 자동으로 로드된다.
다른 소스 파일에서 인라인 템플릿을 사용하려면 명시적으로 `enable :inline_templates`을 호출하면 됨.

### 이름을 가지는 템플릿(Named Templates)

템플릿은 톱 레벨(top-level)에서 `template`메서드를 사용하여 정의할 수 있다:

```ruby
template :layout do
  "%html\n  =yield\n"
end

template :index do
  '%div.title Hello World!'
end

get '/' do
  haml :index
end
```

"layout"이라는 이름의 템플릿이 존재하면, 매번 템플릿이 렌더될 때마다 사용될 것이다.
이 때 `:layout => false`를 전달하여 개별적으로 레이아웃을 비활성시키거나
또는 `set :haml, :layout => false`으로 기본값을 비활성으로 둘 수 있다:

```ruby
get '/' do
  haml :index, :layout => !request.xhr?
end
```

### 파일 확장자 연결하기

어떤 파일 확장자를 특정 템플릿 엔진과 연결하려면, `Tilt.register`를 사용하면 된다.
예를 들어, `tt`라는 파일 확장자를 Textile 템플릿과 연결하고 싶다면, 다음과 같이 하면 된다:

```ruby
Tilt.register :tt, Tilt[:textile]
```

### 나만의 고유한 템플릿 엔진 추가하기

우선, Tilt로 여러분 엔진을 등록하고, 그런 다음 렌더링 메서드를 생성하자:

```ruby
Tilt.register :myat, MyAwesomeTemplateEngine

helpers do
  def myat(*args) render(:myat, *args) end
end

get '/' do
  myat :index
end
```

`./views/index.myat` 를 렌더함. 
Tilt에 대한 더 자세한 내용은 https://github.com/rtomayko/tilt 참조.

## 필터(Filters)

사전 필터(before filter)는 라우터와 동일한 맥락에서 매 요청 전에 평가되며 요청과 응답을 변형할 수 있다.
필터에서 설정된 인스턴스 변수들은 라우터와 템플릿 속에서 접근 가능하다:

```ruby
before do
  @note = 'Hi!'
  request.path_info = '/foo/bar/baz'
end

get '/foo/*' do
  @note #=> 'Hi!'
  params[:splat] #=> 'bar/baz'
end
```

사후 필터(after filter)는 라우터와 동일한 맥락에서 매 요청 이후에 평가되며 마찬가지로 요청과 응답을 변형할 수 있다.
사전 필터와 라우터에서 설정된 인스턴스 변수들은 사후 필터에서 접근 가능하다:

```ruby
after do
  puts response.status
end
```

참고: 만약 라우터에서 `body` 메서드를 사용하지 않고 그냥 문자열만 반환한 경우라면, body는 나중에 생성되는 탓에, 아직 사후 필터에서 사용할 수 없을 것이다.

필터는 선택적으로 패턴을 취할 수 있으며, 이 경우 요청 경로가 그 패턴과 매치할 경우에만 필터가 평가될 것이다.

```ruby
before '/protected/*' do
  authenticate!
end

after '/create/:slug' do |slug|
  session[:last_slug] = slug
end
```

라우터와 마찬가지로, 필터 역시 조건을 갖는다:

```ruby
before :agent => /Songbird/ do
  # ...
end

after '/blog/*', :host_name => 'example.com' do
  # ...
end
```

## 헬퍼(Helpers)

톱-레벨의 `helpers` 메서드를 사용하여 라우터 핸들러와 템플릿에서 사용할 헬퍼 메서드들을 정의할 수 있다:

```ruby
helpers do
  def bar(name)
    "#{name}bar"
  end
end

get '/:name' do
  bar(params[:name])
end
```

또는, 헬퍼 메서드는 별도의 모듈 속에 정의할 수도 있다:

```ruby
module FooUtils
  def foo(name) "#{name}foo" end
end

module BarUtils
  def bar(name) "#{name}bar" end
end

helpers FooUtils, BarUtils
```

이 경우 모듈을 애플리케이션 클래스에 포함(include)시킨 것과 동일한 효과를 갖는다.

### 세션(Sessions) 사용하기

세션은 요청 동안에 상태를 유지하기 위해 사용한다. 
세션이 활성화되면, 사용자 세션 당 session 해시 하나씩을 갖게 된다:

```ruby
enable :sessions

get '/' do
  "value = " << session[:value].inspect
end

get '/:value' do
  session[:value] = params[:value]
end
```

`enable :sessions`은 실은 모든 데이터를 쿠키 속에 저장함에 유의하자.
항상 이렇게 하고 싶지 않을 수도 있을 것이다(예를 들어, 많은 양의 데이터를 저장하게 되면 트래픽이 높아진다).
이 때는 여러 가지 랙 세션 미들웨어(Rack session middleware)를 사용할 수 있을 것이다:
이렇게 할 경우라면, `enable :sessions`을 호출하지 *말고*, 
대신 여러분이 선택한 미들웨어를 다른 모든 미들웨어들처럼 포함시키면 된다:

```ruby
use Rack::Session::Pool, :expire_after => 2592000

get '/' do
  "value = " << session[:value].inspect
end

get '/:value' do
  session[:value] = params[:value]
end
```

보안을 위해서, 쿠키 속의 세션 데이터는 세션 시크릿(secret)으로 사인(sign)된다. 
Sinatra는 여러분을 위해 무작위 시크릿을 생성한다.
그렇지만, 이 시크릿은 여러분 애플리케이션 시작 시마다 변경될 수 있기 때문에,
여러분은 여러분 애플리케이션의 모든 인스턴스들이 공유할 시크릿을 직접 만들고 싶을 수도 있다:

```ruby
set :session_secret, 'super secret'
```

조금 더 세부적인 설정이 필요하다면, `sessions` 설정에서 옵션이 있는 해시를 저장할 수도 있을 것이다:

```ruby
set :sessions, :domain => 'foo.com'
```

### 중단하기(Halting)

필터나 라우터에서 요청을 즉각 중단하고 싶을 때 사용하라:

```ruby
halt
```

중단할 때 상태를 지정할 수도 있다:

```ruby
halt 410
```

또는 본문을 넣을 수도 있다:

```ruby
halt 'this will be the body'
```

또는 둘 다도 가능하다:

```ruby
halt 401, 'go away!'
```

헤더를 추가할 경우에는 다음과 같이 하면 된다:

```ruby
halt 402, {'Content-Type' => 'text/plain'}, 'revenge'
```

물론 `halt`를 템플릿과 결합하는 것도 가능하다:

```ruby
halt erb(:error)
```

### 넘기기(Passing)

라우터는 `pass`를 사용하여 다음 번 매칭되는 라우터로 처리를 넘길 수 있다:

```ruby
get '/guess/:who' do
  pass unless params[:who] == 'Frank'
  'You got me!'
end

get '/guess/*' do
  'You missed!'
end
```

이 떄 라우터 블록에서 즉각 빠져나오게 되고 제어는 다음 번 매칭되는 라우터로 넘어간다.
만약 매칭되는 라우터를 찾지 못하면, 404가 반환된다.

### 다른 라우터 부르기(Triggering Another Route)

경우에 따라서는 `pass`가 아니라, 다른 라우터를 호출한 결과를 얻고 싶은 경우도 있을 것이다.
이 때는 간단하게 +`call`+을 사용하면 된다:

```ruby
get '/foo' do
  status, headers, body = call env.merge("PATH_INFO" => '/bar')
  [status, headers, body.map(&:upcase)]
end

get '/bar' do
"bar"
end
```

위 예제의 경우, `"bar"`를 헬퍼로 옮겨 `/foo`와 `/bar` 모두에서 사용하도록 함으로써
테스팅을 쉽게 하고 성능을 높일 수 있을 것이다.

만약 그 요청이 사본이 아닌 바로 그 동일 인스턴스로 보내지도록 하고 싶다면, 
`call` 대신 `call!`을 사용하면 된다.

`call`에 대한 더 자세한 내용은 Rack 명세를 참고하면 된다.

### 본문, 상태 코드 및 헤더 설정하기

라우터 블록의 반환값과 함께 상태 코드(status code)와 응답 본문(response body)을 설정하는 것은 가능하기도 하거니와 권장되는 방법이다. 그렇지만, 경우에 따라서는 본문을 실행 흐름 중의 임의 지점에서 설정하고 싶을 수도 있다.
이 때는 `body` 헬퍼 메서드를 사용하면 된다.
이렇게 하면, 그 순간부터 본문에 접근할 때 그 메서드를 사용할 수가 있다:

```ruby
get '/foo' do
  body "bar"
end

after do
  puts body
end
```

`body`로 블록을 전달하는 것도 가능하며, 이 블록은 랙(Rack) 핸들러에 의해 실행될 것이다.
(이 방법은 스트리밍을 구현할 때 사용할 수 있는데, "값 반환하기"를 참고).

본문와 마찬가지로, 상태코드와 헤더도 설정할 수 있다:

```ruby
get '/foo' do
  status 418
  headers \
"Allow"   => "BREW, POST, GET, PROPFIND, WHEN",
"Refresh" => "Refresh: 20; http://www.ietf.org/rfc/rfc2324.txt"
  body "I'm a tea pot!"
end
```

`body`처럼, `header`와 `status`도 매개변수 없이 사용하여 그것의 현재 값을 액세스하는 데 사용될 수 있다.

### 응답 스트리밍(Streaming Responses)

응답 본문의 일정 부분을 계속 생성하는 가운데 데이터를 내보내기 시작하고 싶을 경우도 있을 것이다.
극단적인 예제로, 클라이언트가 접속을 끊기 전까지 계속 데이터를 내보내고 싶을 수도 있다.
여러분만의 래퍼(wrapper)를 만들기 싫다면 `stream` 헬퍼를 사용하면 된다:

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

이렇게 하면 스트리밍 API나 
[서버 발송 이벤트Server Sent Events](http://dev.w3.org/html5/eventsource/)를 구현할 수 있게 해 주며,
[WebSockets](http://en.wikipedia.org/wiki/WebSocket)을 위한 기반으로 사용될 수 있다.
또한 이 방법은 일부 콘텐츠가 느린 자원에 의존하는 경우에 
스로풋(throughtput)을 높이기 위해 사용될 수도 있다.

스트리밍 동작, 특히 동시 요청의 수는 애플리케이션을 서빙하는 웹서버에 크게 의존적이다.
어떤 서버, 예컨대 WEBRick 같은 경우는 아예 스트리밍을 지원조차 하지 못할 것이다.
만약 서버가 스트리밍을 지원하지 않는다면, 본문은 `stream` 으로 전달된 블록이 수행을 마친 후에 한꺼번에 반환될 것이다.
스트리밍은 Shotgun에서는 작동하지 않는다. 

만약 선택적 매개변수 `keep_open`이 설정되어 있다면, 스트림 객체에서 `close`를 호출하지 않을 것이고,
따라서 여러분은 나중에 실행 흐름 상의 어느 시점에서 스트림을 닫을 수 있다.
이 옵션은 Thin과 Rainbow 같은 이벤트 기반 서버에서만 작동한다.
다른 서버들은 여전히 스트림을 닫을 것이다:

```ruby
set :server, :thin
connections = []

get '/' do
  # 스트림을 열린 채 유지
  stream(:keep_open) { |out| connections << out }
end

post '/' do
  # 모든 열린 스트림에 쓰기
  connections.each { |out| out << params[:message] << "\n" }
  "message sent"
end
```

### 로깅(Logging)

In the request scope, the `logger` helper exposes a `Logger` instance:
요청 스코프(request scope) 내에서, `Logger`의 인스턴스인 `logger` 헬퍼를 사용할 수 있다: 

```ruby
get '/' do
  logger.info "loading data"
  # ...
end
```

이 로거는 여러분이 Rack 핸들러에서 설정한 로그 셋팅을 자동으로 참고한다.
만약 로깅이 비활성이라면, 이 메서드는 더미(dummy) 객체를 반환할 것이며,
따라서 여러분은 라우터나 필터에서 이 부분에 대해 걱정할 필요는 없다.

로깅은 `Sinatra::Application`에서만 기본으로 활성화되어 있음에 유의하자.
만약 `Sinatra::Base`로부터 상속받은 경우라면 직접 활성화시켜 줘야 한다:

```ruby
class MyApp < Sinatra::Base
  configure :production, :development do
enable :logging
  end
end
```

어떠한 로깅 미들웨어도 설정되지 않게 하려면, `logging` 설정을 `nil`로 두면 된다.
그렇지만, 이럴 경우 `logger`는 `nil`을 반환할 것임에 유의하자.
통상적인 유스케이스는 여러분만의 로거를 사용하고자 할 경우일 것이다.
Sinatra는 `env['rack.logger']`에서 찾은 것을 사용할 것이다.

### 마임 타입(Mime Types)

`send_file`이나 정적인 파일을 사용할 때에 Sinatra가 인식하지 못하는 마임 타입이 있을 수 있다.
이 경우 `mime_type`을 사용하여 파일 확장자를 등록하면 된다:

```ruby
configure do
  mime_type :foo, 'text/foo'
end
```

또는 `content_type` 헬퍼와 함께 사용할 수도 있다:

```ruby
get '/' do
  content_type :foo
  "foo foo foo"
end
```

### URL 생성하기

URL을 생성하려면 `url` 헬퍼 메서드를 사용해야 한다. 예를 들어 Haml에서:

```ruby
%a{:href => url('/foo')} foo
```

이것은 리버스 프록시(reverse proxies)와 Rack 라우터를, 만약 존재한다면, 참고한다.

This method is also aliased to `to` (see below for an example).
이 메서드는 `to`라는 별칭으로도 사용할 수 있다 (아래 예제 참조).

### 브라우저 재지정(Browser Redirect)

`redirect` 헬퍼 메서드를 사용하여 브라우저 리다이렉트를 촉발시킬 수 있다:

```ruby
get '/foo' do
  redirect to('/bar')
end
```

여타 부가적인 매개변수들은 `halt`에서 전달한 인자들처럼 다루어 진다:

```ruby
redirect to('/bar'), 303
redirect 'http://google.com', 'wrong place, buddy'
```

`redirect back`을 사용하면 사용자가 왔던 페이지로 다시 돌아가는 리다이렉트도 쉽게 할 수 있다:

```ruby
get '/foo' do
  "<a href='/bar'>do something</a>"
end

get '/bar' do
  do_something
  redirect back
end
```

리다이렉트와 함께 인자를 전달하려면, 쿼리에 붙이거나:

```ruby
redirect to('/bar?sum=42')
```

또는 세션을 사용하면 된다:

```ruby
enable :sessions

get '/foo' do
  session[:secret] = 'foo'
  redirect to('/bar')
end

get '/bar' do
  session[:secret]
end
```

### 캐시 컨트롤(Cache Control)

헤더를 정확하게 설정하는 것은 적절한 HTTP 캐싱의 기본이다. 

Cache-Control 헤더를 다음과 같이 간단하게 설정할 수 있다:

```ruby
get '/' do
  cache_control :public
  "cache it!"
end
```

프로 팁: 캐싱은 사전 필터에서 설정하라:

```ruby
before do
  cache_control :public, :must_revalidate, :max_age => 60
end
```

`expires` 헬퍼를 사용하여 그에 상응하는 헤더를 설정한다면,
`Cache-Control`이 자동으로 설정될 것이다:

```ruby
before do
  expires 500, :public, :must_revalidate
end
```

캐시를 잘 사용하려면, `etag` 또는 `last_modified`의 사용을 고려해야 할 것이다.
무거운 작업을 하기 *전*에 이들 헬퍼를 호출할 것을 권장하는데,
이러면 만약 클라이언트 캐시에 현재 버전이 이미 들어 있을 경우엔 즉각 응답을 반환(flush)하게 될 것이다:

```ruby
get '/article/:id' do
  @article = Article.find params[:id]
  last_modified @article.updated_at
  etag @article.sha1
  erb :article
end
```

[약한 ETag](http://en.wikipedia.org/wiki/HTTP_ETag#Strong_and_weak_validation)를 사용하는 것도 가능하다:

```ruby
etag @article.sha1, :weak
```

이들 헬퍼는 어떠한 캐싱도 하지 않으며, 대신 필요한 정보를 캐시에 제공한다.
여러분이 만약 손쉬운 리버스 프록시(reverse-proxy) 캐싱 솔루션을 찾고 있다면,
[rack-cache](https://github.com/rtomayko/rack-cache)를 써보라:

```ruby
require "rack/cache"
require "sinatra"

use Rack::Cache

get '/' do
  cache_control :public, :max_age => 36000
  sleep 5
  "hello"
end
```

정적 파일에 `Cache-Control` 헤더 정보를 추가하려면 `:static_cache_control` 설정(아래 참조)을 사용하라:

RFC 2616에 따르면 If-Match 또는 If-None-Match 헤더가 `*`로 설정된 경우 요청한 리소스(resource)가 이미 존재하느냐 여부에 따라 다르게 취급해야 한다고 되어 있다.
Sinatra는 (get 처럼) 안전하거나 (put 처럼) 멱등인 요청에 대한 리소스는 이미 존재한다고 가정하며, 
반면 다른 리소스(예를 들면 post 요청 같은)의 경우는 새 리소스로 취급한다.
이런 설정은 `:new_resource` 옵션으로 전달하여 변경할 수 있다:

```ruby
get '/create' do
  etag '', :new_resource => true
  Article.create
  erb :new_article
end
```

여전히 약한 ETag를 사용하고자 한다면, `:kind`으로 전달하자:

```ruby
etag '', :new_resource => true, :kind => :weak
```

### 파일 전송하기(Sending Files)

파일을 전송하려면, `send_file` 헬퍼 메서드를 사용하면 된다:

```ruby
get '/' do
  send_file 'foo.png'
end
```

이 메서드는 몇 가지 옵션을 받는다:

```ruby
send_file 'foo.png', :type => :jpg
```

옵션들:

<dl>
  <dt>filename</dt>
  <dd>응답에서의 파일명. 기본값은 실제 파일명이다.</dd>

  <dt>last_modified</dt>
  <dd>Last-Modified 헤더값. 기본값은 파일의 mtime.</dd>

  <dt>type</dt>
  <dd>사용할 컨텐츠 유형. 없으면 파일 확장자로부터 유추된다.</dd>

  <dt>disposition</dt>
  <dd>Content-Disposition에서 사용됨. 가능한 값들: <tt>nil</tt> (기본값),
<tt>:attachment</tt> 및 <tt>:inline</tt></dd>

  <dt>length</dt>
  <dd>Content-Length, 기본값은 파일 크기.</dd>

  <dt>status</dt>
  <dd>전송할 상태 코드. 오류 페이지로 정적 파일을 전송할 경우에 유용.</dd>
</dl>

Rack 핸들러가 지원할 경우, Ruby 프로세스로부터의 스트리밍이 아닌 다른 수단을 사용할 수 있다.
만약 이 헬퍼 메서드를 사용하게 되면, Sinatra는 자동으로 범위 요청(range request)을 처리할 것이다.

### 요청 객체에 접근하기(Accessing the Request Object)

인입되는 요청 객에는 요청 레벨(필터, 라우터, 오류 핸들러)에서 `request` 메서드를 통해 접근 가능하다: 

```ruby
# http://example.com/example 상에서 실행 중인 앱
get '/foo' do
  t = %w[text/css text/html application/javascript]
  request.accept              # ['text/html', '*/*']
  request.accept? 'text/xml'  # true
  request.preferred_type(t)   # 'text/html'
  request.body                # 클라이언트로부터 전송된 요청 본문 (아래 참조)
  request.scheme              # "http"
  request.script_name         # "/example"
  request.path_info           # "/foo"
  request.port                # 80
  request.request_method      # "GET"
  request.query_string        # ""
  request.content_length      # request.body의 길이
  request.media_type          # request.body의 미디어 유형
  request.host                # "example.com"
  request.get?                # true (다른 동사에 대해 유사한 메서드 있음)
  request.form_data?          # false
  request["SOME_HEADER"]      # SOME_HEADER 헤더의 값
  request.referrer            # 클라이언트의 리퍼러 또는 '/'
  request.user_agent          # 사용자 에이전트 (:agent 조건에서 사용됨)
  request.cookies             # 브라우저 쿠키의 해시
  request.xhr?                # 이게 ajax 요청인가요?
  request.url                 # "http://example.com/example/foo"
  request.path                # "/example/foo"
  request.ip                  # 클라이언트 IP 주소
  request.secure?             # false (ssl 접속인 경우 true)
  request.forwarded?          # true (리버스 프록시 하에서 작동 중이라면)
  request.env                 # Rack에 의해 처리되는 로우(raw) env 해시
end
```

일부 옵션들, `script_name` 또는 `path_info`와 같은 일부 옵션은 쓸 수도 있다:

```ruby
before { request.path_info = "/" }

get "/" do
  "all requests end up here"
end
```

`request.body`는 IO 또는 StringIO 객체이다:

```ruby
post "/api" do
  request.body.rewind  # 누군가 이미 읽은 경우
  data = JSON.parse request.body.read
  "Hello #{data['name']}!"
end
```

### 첨부(Attachments)

`attachment` 헬퍼를 사용하여 브라우저에게 응답이 브라우저에 표시되는 게 아니라 
디스크에 저장되어야 함을 알릴 수 있다:

```ruby
get '/' do
  attachment
  "store it!"
end
```

이 때 파일명을 전달할 수도 있다:

```ruby
get '/' do
  attachment "info.txt"
  "store it!"
end
```

### 날짜와 시간 다루기

Sinatra는 `time_for_` 헬퍼 메서드를 제공하는데, 이 메서드는 주어진 값으로부터 Time 객체를 생성한다.
`DateTime` 이나 `Date` 또는 유사한 클래스들도 변환 가능하다:

```ruby
get '/' do
  pass if Time.now > time_for('Dec 23, 2012')
  "still time"
end
```

이 메서드는 내부적으로 `expires` 나 `last_modified` 같은 곳에서 사용된다.
따라서 여러분은 애플리케이션에서 `time_for`를 오버라이딩하여 
이들 메서드의 동작을 쉽게 확장할 수 있다:

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

### 템플릿 파일 참조하기

`find_template`는 렌더링할 템플릿 파일을 찾는데 사용된다:

```ruby
find_template settings.views, 'foo', Tilt[:haml] do |file|
  puts "could be #{file}"
end
```

This is not really useful. But it is useful that you can actually override this
method to hook in your own lookup mechanism. For instance, if you want to be
able to use more than one view directory:
이건 별로 유용하지 않다. 그렇지만 이 메서드를 오버라이드하여 여러분만의 참조 메커니즘에서 가로채는 것은 유용하다.
예를 들어, 하나 이상의 뷰 디렉터리를 사용하고자 한다면:

```ruby
set :views, ['views', 'templates']

helpers do
  def find_template(views, name, engine, &block)
    Array(views).each { |v| super(v, name, engine, &block) }
  end
end
```

또다른 예제는 각각의 엔진마다 다른 디렉터리를 사용할 경우다:

```ruby
set :views, :sass => 'views/sass', :haml => 'templates', :default => 'views'

helpers do
  def find_template(views, name, engine, &block)
    _, folder = views.detect { |k,v| engine == Tilt[k] }
    folder ||= views[:default]
    super(folder, name, engine, &block)
  end
end
```

여러분은 이것을 간단하게 확장(extension)으로 만들어 다른 사람들과 공유할 수 있다!

`find_template`은 그 파일이 실제 존재하는지 검사하지 않음에 유의하자.
대신 모든 가능한 경로에 대해 주어진 블록을 호출할 뿐이다.
이것은 성능 문제는 아닌 것이, `render`는 파일이 발견되는 즉시 `break`를 사용할 것이기 때문이다.
또한, 템플릿 위치(그리고 콘텐츠)는 개발 모드에서 실행 중이 아니라면 캐시될 것이다.
정말로 멋진 메세드를 작성하고 싶다면 이 점을 명심하자.

## 설정(Configuration)

모든 환경에서, 시작될 때, 한번만 실행:

```ruby
configure do
  # 옵션 하나 설정
  set :option, 'value'
  
  # 여러 옵션 설정
  set :a => 1, :b => 2
  
  # `set :option, true`와 동일
  enable :option
  
  # `set :option, false`와 동일
  disable :option
  
  # 블록으로 동적인 설정을 할 수도 있음
  set(:css_dir) { File.join(views, 'css') }
end
```

환경(RACK_ENV 환경 변수)이 `:production`일 때만 실행:

```ruby
configure :production do
  ...
end
```

환경이 `:production` 또는 `:test`일 때 실행:

```ruby
configure :production, :test do
  ...
end
```

이들 옵션은 `settings`를 통해 접근 가능하다:

```ruby
configure do
  set :foo, 'bar'
end

get '/' do
  settings.foo? # => true
  settings.foo  # => 'bar'
  ...
end
```

### 공격 방어 설정하기(Configuring attack protection)

Sinatra는 [Rack::Protection](https://github.com/rkh/rack-protection#readme)을 사용하여 
일반적인, 일어날 수 있는 공격에 대비한다. 
이 부분은 간단하게 비활성시킬 수 있다(성능 향상 효과를 가져올 것이다):

```ruby
disable :protection
```

하나의 방어층만 스킵하려면, 옵션 해시에 `protection`을 설정하면 된다:

```ruby
set :protection, :except => :path_traversal
```

방어막 여러 개를 비활성하려면, 배열로 주면 된다:

```ruby
set :protection, :except => [:path_traversal, :session_hijacking]
```

### 가능한 설정들(Available Settings)

<dl>
  <dt>absolute_redirects</dt>
  <dd>
    만약 비활성이면, Sinatra는 상대경로 리다이렉트를 허용할 것이지만,
    이렇게 되면 Sinatra는 더 이상 오직 절대경로 리다이렉트만 허용하고 있는
    RFC 2616(HTTP 1.1)에 위배될 것이다.

    적정하게 설정되지 않은 리버스 프록시 하에서 앱을 실행 중이라면 활성화시킬 것.
    <tt>rul</tt> 헬퍼는, 만약 두 번째 매개변수로 <tt>false</tt>를 전달하지만 않는다면,
    여전히 절대경로 URL을 생성할 것임에 유의하자.

   기본값은 비활성.
  </dd>

  <dt>add_charsets</dt>
  <dd>
    <tt>content_type</tt>가 문자셋 정보에 자동으로 추가하게 될 마임(mime) 타입.

     이 옵션은 오버라이딩하지 말고 추가해야 한다:

    <tt>settings.add_charsets << "application/foobar"</tt>
  </dd>

  <dt>app_file</dt>
  <dd>메인 애플리케이션 파일의 경로. 프로젝트 루트와 뷰, 그리고 public 폴더, 인라인 템플릿을
   파악할 때 사용됨.
  </dd>

  <dt>bind</dt>
  <dd>바인드할 IP 주소(기본값: 0.0.0.0).
   오직 빌트인(built-in) 서버에서만 사용됨.
  </dd>

  <dt>default_encoding</dt>
  <dd>모를 때 가정할 인코딩
   (기본값은 <tt>"utf-8"</tt>).
  </dd>

  <dt>dump_errors</dt>
  <dd>
    로그로 에러 출력.
  </dd>

  <dt>environment</dt>
  <dd>현재 환경, 기본값은 <tt>ENV['RACK_ENV']</tt> 또는 알 수 없을 경우 "development".</dd>

  <dt>logging</dt>
  <dd>로거(logger) 사용.</dd>

  <dt>lock</dt>
  <dd>매 요청에 걸쳐 잠금(lock)을 설정. Ruby 프로세스 당 요청을 동시에 할 경우.

   앱이 스레드 안전(thread-safe)이 아니라면 활성화시킬 것.
   기본값은 비활성.</dd>

  <dt>method_override</dt>
  <dd>put/delete를 지원하지 않는 브라우저에서 put/delete 폼을 허용하는
   <tt>_method</tt> 꼼수 사용.</dd>

  <dt>port</dt>
  <dd>접속 포트. 빌트인 서버에서만 사용됨.</dd>

  <dt>prefixed_redirects</dt>
  <dd>절대경로가 주어지지 않은 리다이렉트에 <tt>request.script_name</tt>를
   삽입할지 여부. 이렇게 하면 <tt>redirect '/foo'</tt>는 <tt>redirect to('/foo')</tt>
   처럼 동작. 기본값은 비활성.</dd>

  <dt>protection</dt>
  <dd>웹 공격 방어를 활성화시킬 건지 여부. 위의 보안 섹션 참조.</dd>

  <dt>public_folder</dt>
  <dd>public 파일이 제공될 폴더의 경로.
   static 파일 제공이 활성화된 경우만 사용됨(아래 <tt>static</tt>참조).
   만약 설정이 없으면 <tt>app_file</tt>로부터 유추됨.</dd>

  <dt>reload_templates</dt>
  <dd>요청 간에 템플릿을 리로드(reload)할 건지 여부.
   개발 모드에서는 활성됨.</dd>

  <dt>root</dt>
  <dd>프로젝트 루트 디렉터리 경로. 
   설정이 없으면 <tt>app_file</tt> 설정으로부터 유추됨.</dd>

  <dt>raise_errors</dt>
  <dd>예외 발생(애플리케이션은 중단됨).
   기본값은 <tt>environment</tt>가 <tt>"test"</tt>인 경우는 활성, 그렇지 않으면 비활성.</dd>

  <dt>run</dt>
  <dd>활성화되면, Sinatra가 웹서버의 시작을 핸들링.
   rackup 또는 다른 도구를 사용하는 경우라면 활성화시키지 말 것.</dd>

  <dt>running</dt>
  <dd>빌트인 서버가 실행 중인지?
   이 설정은 변경하지 말 것!</dd>

  <dt>server</dt>
  <dd>
    빌트인 서버로 사용할 서버 또는 서버 목록.
    기본값은 ['thin', 'mongrel', 'webrick']이며 순서는 우선순위를 의미.
  </dd>
  <dt>sessions</dt>
  <dd><tt>Rack::Session::Cookie</tt>를 사용한 쿠키 기반 세션 활성화.
   보다 자세한 정보는 '세션 사용하기' 참조.</dd>

  <dt>show_exceptions</dt>
  <dd>예외 발생 시에 브라우저에 스택 추적을 보임.
   기본값은 <tt>environment</tt>가 <tt>"development"</tt>인 경우는 활성, 나머지는 비활성.
  </dd>

  <dt>static</dt>
  <dd>Sinatra가 정적(static) 파일을 핸들링할 지 여부.
   이 기능을 수행하는 서버를 사용하는 경우라면 비활성시킬 것.
   비활성시키면 성능이 올라감.
   기본값은 전통적 방식에서는 활성, 모듈 앱에서는 비활성.</dd>

  <dt>static_cache_control</dt>
  <dd>Sinatra가 정적 파일을 제공하는 경우, 응답에 <tt>Cache-Control</tt> 헤더를 추가할 때 설정.
   <tt>cache_control</tt> 헬퍼를 사용.
   기본값은 비활성.
   여러 값을 설정할 경우는 명시적으로 배열을 사용할 것:
   <tt>set :static_cache_control, [:public, :max_age => 300]</tt>
  </dd>

  <dt>threaded</dt>
  <dd><tt>true</tt>로 설정하면, Thin이 요청을 처리하는데 있어 <tt>EventMachine.defer</tt>를 사용하도록 함. </dd>

  <dt>views</dt>
  <dd>뷰 폴더 경로. 설정하지 않은 경우 <tt>app_file</tt>로부터 유추됨.</dd>
</dl>


## 환경(Environments)

환경은 `RACK_ENV` 환경 변수를 통해서도 설정할 수 있다. 기본값은 "development"다.
이 모드에서, 모든 템플릿들은 요청 간에 리로드된다.
특별한 `not_found` 와 `error` 핸들러가 이 환경에 설치되기 때문에
브라우저에서 스택 추적을 볼 수 있을 것이다.
`"production"`과 `"test"`에서는 템플릿은 캐시되는 게 기본값이다.

다른 환경으로 실행시키려면 `-e`옵션을 사용하면 된다:

```ruby
ruby my_app.rb -e [ENVIRONMENT]
```

현재 설정된 환경이 무엇인지 검사하기 위해 사전 정의된 `development?`, `test?` 및 `production?` 메서드를
사용할 수 있다.

## 예외 처리(Error Handling)

예외 핸들러는 라우터 및 사전 필터와 동일한 맥락에서 실행된다. 
이 말인즉, 이들이 제공하는 모든 것들을 사용할 수 있다는 말이다. 예를 들면 `haml`,
`erb`, `halt`, 등등.

### 찾을 수 없음(Not Found)

`Sinatra::NotFound` 예외가 발생하거나 또는 응답의 상태 코드가 404라면,
`not_found` 핸들러가 호출된다:

```ruby
not_found do
  '아무 곳에도 찾을 수 없습니다.'
end
```

### 오류(Error)

`error` 핸들러는 라우터 또는 필터에서 뭐든 오류가 발생할 경우에 호출된다.
예외 객체는 Rack 변수 `sinatra.error`로부터 얻을 수 있다:

```ruby
error do
  '고약한 오류가 발생했군요 - ' + env['sinatra.error'].name
end
```

사용자 정의 오류:

```ruby
error MyCustomError do
  '무슨 일이 생겼나면요...' + env['sinatra.error'].message
end
```

그런 다음, 이 오류가 발생하면:

```ruby
get '/' do
  raise MyCustomError, '안좋은 일'
end
```

다음을 얻는다:

```ruby
무슨 일이 생겼냐면요... 안좋은 일
```

또는, 상태 코드에 대해 오류 핸들러를 설치할 수 있다:

```ruby
error 403 do
  '액세스가 금지됨'
end

get '/secret' do
  403
end
```

Or a range:

```ruby
error 400..510 do
  '어이쿠'
end
```

Sinatra는 개발 환경에서 동작할 경우에 
특별한 `not_found` 와 `error` 핸들러를 설치한다.

## Rack 미들웨어(Rack Middleware)

Sinatra는 [Rack](http://rack.rubyforge.org/) 위에서 동작하며,
Rack은 루비 웹 프레임워크를 위한 최소한의 표준 인터페이스이다.
Rack이 애플리케이션 개발자들에게 제공하는 가장 흥미로운 기능 중 하나가 바로
"미들웨어(middleware)"에 대한 지원이며, 여기서 미들웨어란 서버와 여러분의 애플리케이션 사이에
위치하면서 HTTP 요청/응답을 모니터링하거나/또는 조작함으로써
다양한 유형의 공통 기능을 제공하는 컴포넌트(component)다.

Sinatra는 톱레벨의 `use` 메서드를 사용하여 Rack 미들웨어의 파이프라인을 만드는 일을 식은 죽 먹기로 만든다:

```ruby
require 'sinatra'
require 'my_custom_middleware'

use Rack::Lint
use MyCustomMiddleware

get '/hello' do
  'Hello World'
end
```

`use`의 의미는 [Rack::Builder](http://rack.rubyforge.org/doc/classes/Rack/Builder.html]) DSL
(rackup 파일에서 가장 많이 사용된다)에서 정의한 것들과 동일하다.
예를 들어, `use` 메서드는 블록 뿐 아니라 여러 개의/가변적인 인자도 받는다:

```ruby
use Rack::Auth::Basic do |username, password|
  username == 'admin' && password == 'secret'
end
```

Rack은 로깅, 디버깅, URL 라우팅, 인증, 그리고 세센 핸들링을 위한 다양한 표준 미들웨어로 분산되어 있다.
Sinatra는 설정에 기반하여 이들 컴포넌트들 중 많은 것들을 자동으로 사용하며,
따라서 여러분은 일반적으로는 `use`를 명시적으로 사용할 필요가 없을 것이다.

유용한 미들웨어들은 
[rack](https://github.com/rack/rack/tree/master/lib/rack),
[rack-contrib](https://github.com/rack/rack-contrib#readme),
[CodeRack](http://coderack.org/) 또는
[Rack wiki](https://github.com/rack/rack/wiki/List-of-Middleware)
에서 찾을 수 있다.

## 테스팅(Testing)

Sinatra 테스트는 Rack 기반 어떠한 테스팅 라이브러리 또는 프레임워크를 사용하여도 작성할 수 있다.
[Rack::Test](http://rdoc.info/github/brynary/rack-test/master/frames)를 권장한다:

```ruby
require 'my_sinatra_app'
require 'test/unit'
require 'rack/test'

class MyAppTest < Test::Unit::TestCase
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
```

## Sinatra::Base - 미들웨어(Middleware), 라이브러리(Libraries), 그리고 모듈 앱(Modular Apps)

톱레벨에서 앱을 정의하는 것은 마이크로 앱(micro-app) 수준에서는 잘 동작하지만,
Rack 미들웨어나, Rails 메탈(metal) 또는 서버 컴포넌트를 갖는 간단한 라이브러리, 또는 더 나아가
Sinatra 익스텐션(extension) 같은 재사용 가능한 컴포넌트들을 구축할 경우에는 심각한 약점을 가진다.
톱레벨은 마이크로 앱 스타일의 설정을 가정한다(즉, 하나의 단일 애플리케이션 파일과 
`./public` 및 `./views` 디렉터리, 로깅, 예외 상세 페이지 등등).
이게 바로 `Sinatra::Base`가 필요한 부분이다:

```ruby
require 'sinatra/base'

class MyApp < Sinatra::Base
  set :sessions, true
  set :foo, 'bar'
  
  get '/' do
    'Hello world!'
  end
end
```

`Sinatra::Base` 서브클래스에서 사용가능한 메서드들은 톱레벨 DSL로 접근 가능한 것들과 동일하다.
대부분의 톱레벨 앱들이 다음 두 가지만 수정하면 `Sinatra::Base` 컴포넌트로 변환 가능하다:

* 파일은 `sinatra`가 아닌 `sinatra/base`를 require해야 하며, 그렇지 않으면
모든 Sinatra의 DSL 메서드들이 메인 네임스페이스에 불러지게 된다.
* 앱의 라우터, 예외 핸들러, 필터, 그리고 옵션들을 `Sinatra::Base`의 서브클래스에 둘 것.

`Sinatra::Base`는 빈서판(blank slate)이다.
빌트인 서버를 비롯한 대부분의 옵션들이 기본값으로 꺼져 있다.
가능한 옵션들과 그 작동에 대한 상세는 [Options and Configuration](http://sinatra.github.com/configuration.html)을 참조할 것.

### 모듈(Modular) vs. 전통적 방식(Classic Style)

일반적인 믿음과는 반대로, 전통적 방식에 잘못된 부분은 없다.
여러분 애플리케이션에 맞다면, 모듈 애플리케이션으로 전환할 필요는 없다.

모듈 방식이 아닌 전통적 방식을 사용할 경우 생기는 주된 단점은 루비 프로세스 당
오직 하나의 Sinatra 애플리케이션만 사용할 수 있다는 점이다.
만약 하나 이상을 사용할 계획이라면, 모듈 방식으로 전환하라.
모듈 방식과 전통적 방식을 섞어쓰지 못할 이유는 없다.

하나의 방식에서 다른 것으로 전환할 경우에는, 기본값 설정의 미묘한 차이에 유의해야 한다:

설정전통적 방식   모듈 방식

<table>
  <tr>
    <th>Setting</th>
    <th>Classic</th>
    <th>Modular</th>
  </tr>
  <tr>
    <td>app_file</td>
    <td>sinatra를 로딩하는 파일</td>
    <td>Sinatra::Base를 서브클래싱한 파일</td>
  </tr>
  <tr>
    <td>run</td>
    <td>$0 == app_file</td>
    <td>false</td>
  </tr>
  <tr>
    <td>logging</td>
    <td> true</td>
    <td>false</td>
  </tr>
  <tr>
    <td>method_override</td>
    <td>true</td>
    <td>false</td>
  </tr>
  <tr>
    <td>inline_templates</td>
    <td>true</td>
    <td>false</td>
  </tr>
  <tr>
    <td>static</td>
    <td>true</td>
    <td>false</td>
  </tr>
</table>

### 모듈 애플리케이션(Modular Application) 제공하기

모듈 앱을 시작하는 두 가지 일반적인 옵션이 있는데, 
공격적으로 `run!`으로 시작하거나:

```ruby
# my_app.rb
require 'sinatra/base'

class MyApp < Sinatra::Base
  # ... 여기에 앱 코드가 온다 ...

  # 루비 파일이 직접 실행될 경우에 서버를 시작
  run! if app_file == $0
end
```

다음과 같이 시작:

```ruby
ruby my_app.rb
```

또는 `config.ru`와 함께 사용하며, 이 경우는 어떠한 Rack 핸들러라도 사용할 수 있다:

```ruby
# config.ru
require './my_app'
run MyApp
```

실행:

```ruby
rackup -p 4567
```

### config.ru로 전통적 방식의 애플리케이션 사용하기

앱 파일을 다음과 같이 작성하고:

```ruby
# app.rb
require 'sinatra'

get '/' do
  'Hello world!'
end
```

대응하는 `config.ru`는 다음과 같이 작성:

```ruby
require './app'
run Sinatra::Application
```

### 언제 config.ru를 사용할까?

Good signs you probably want to use a `config.ru`:
다음은 `config.ru`를 사용하게 될 징후들이다:

* 다른 Rack 핸들러(Passenger, Unicorn, Heroku, ...)로 배포하고자 할 때.
* 하나 이상의 `Sinatra::Base` 서브클래스를 사용하고자 할 때.
* Sinatra를 최종점(endpoint)이 아니라, 오로지 미들웨어로만 사용하고자 할 때.

**모듈 방식으로 전환했다는 이유만으로 `config.ru`로 전환할 필요는 없으며,
또한 `config.ru`를 사용한다고 해서 모듈 방식을 사용해야 하는 것도 아니다.**

### Sinatra를 미들웨어로 사용하기

Sinatra에서 다른 Rack 미들웨어를 사용할 수 있을 뿐 아니라,
모든 Sinatra 애플리케이션은 순차로 어떠한 Rack 종착점 앞에 미들웨어로 추가될 수 있다.
이 종착점은 다른 Sinatra 애플리케이션이 될 수도 있고, 
또는 Rack 기반의 어떠한 애플리케이션(Rails/Ramaze/Camping/...)이라도 가능하다:

```ruby
require 'sinatra/base'

class LoginScreen < Sinatra::Base
  enable :sessions
  
  get('/login') { haml :login }
  
  post('/login') do
if params[:name] == 'admin' && params[:password] == 'admin'
  session['user_name'] = params[:name]
else
  redirect '/login'
end
  end
end

class MyApp < Sinatra::Base
  # 미들웨어는 사전 필터보다 앞서 실행됨
  use LoginScreen
  
  before do
unless session['user_name']
  halt "접근 거부됨, <a href='/login'>로그인</a> 하세요."
end
  end
  
  get('/') { "Hello #{session['user_name']}." }
end
```

### 동적인 애플리케이션 생성(Dynamic Application Creation)

경우에 따라선 어떤 상수에 할당하지 않고 런타임에서 새 애플리케이션들을 생성하고 싶을 수도 있을 것인데,
이 때는 `Sinatra.new`를 쓰면 된다:

```ruby
require 'sinatra/base'
my_app = Sinatra.new { get('/') { "hi" } }
my_app.run!
```

이것은 선택적 인자로 상속할 애플리케이션을 받는다:

```ruby
# config.ru
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

이것은 Sintra 익스텐션을 테스팅하거나 또는 여러분의 라이브러리에서 Sinatra를 사용할 경우에 특히 유용하다.

또한 이 방법은 Sinatra를 미들웨어로 사용하는 것을 아주 쉽게 만들어 준다:

```ruby
require 'sinatra/base'

use Sinatra do
  get('/') { ... }
end

run RailsProject::Application
```

## 범위(Scopes)와 바인딩(Binding)

현재 어느 범위에 있느냐가 어떤 메서드와 변수를 사용할 수 있는지를 결정한다.

### 애플리케이션/클래스 범위

모든 Sinatra 애플리케이션은 `Sinatra::Base`의 서브클래스에 대응된다.
만약 톱레벨 DSL (`require 'sinatra'`)을 사용한다면,
이 클래스는 `Sinatra::Application`이며, 그렇지 않을 경우라면 여러분이 명시적으로 생성한 
그 서브클래스가 된다. 클래스 레벨에서는 `get` 이나 `before` 같은 메서드들을 가지나,
`request` 객체나 `session` 에는 접근할 수 없다. 왜냐면 모든 요청에 대해
애플리케이션 클래스는 오직 하나이기 때문이다.

`set`으로 생성한 옵션들은 클래스 레벨의 메서드들이다:

```ruby
class MyApp < Sinatra::Base
  # 이봐요, 저는 애플리케이션 범위에 있다구요!
  set :foo, 42
  foo # => 42

  get '/foo' do
# 저기요, 전 이제 더 이상 애플리케이션 범위 속에 있지 않아요!
  end
end
```

다음 속에 있을 때 애플리케이션 범위가 된다:

* 애플리케이션 클래스 본문
* 확장으로 정의된 메서드
* `helpers`로 전달된 블록
* `set`의 값으로 사용된 Procs/blocks
* `Sinatra.new`로 전달된 블록

범위 객체 (클래스)는 다음과 같이 접근할 수 있다:

* configure 블록으로 전달된 객체를 통해(`configure { |c| ... }`)
* 요청 범위 내에서 `settings`

### 요청/인스턴스 범위

매 요청마다, 애플리케이션 클래스의 새 인스턴스가 생성되고 모든 핸들러 블록은 그 범위 내에서 실행된다.
이 범위 내에서 여러분은 `request` 와 `session` 객체에 접근하거나 
`erb` 나 `haml` 같은 렌더링 메서드를 호출할 수 있다.
요청 범위 내에서 애플리케이션 범위는 `settings` 헬퍼를 통해 접근 가능하다:

```ruby
class MyApp < Sinatra::Base
  # 이봐요, 전 애플리케이션 범위에 있다구요!
  get '/define_route/:name' do
# '/define_route/:name'의 요청 범위
@value = 42
  
settings.get("/#{params[:name]}") do
  # "/#{params[:name]}"의 요청 범위
  @value # => nil (동일한 요청이 아님)
end
  
"라우터가 정의됨!"
  end
end
```

다음 속에 있을 때 요청 범위 바인딩이 된다:

* get/head/post/put/delete/options 블록
* before/after 필터
* 헬퍼(helper) 메서드
* 템플릿/뷰

### 위임 범위(Delegation Scope)

위임 범위(delegation scope)는 메서드를 단순히 클래스 범위로 보낸다(forward).
그렇지만, 100% 클래스 범위처럼 움직이진 않는데, 왜냐면 클래스 바인딩을 갖지 않기 때문이다.
오직 명시적으로 위임(delegation) 표시된 메서드들만 사용 가능하며 
또한 클래스 범위와 변수/상태를 공유하지 않는다 (유의: `self`가 다르다).
`Sinatra::Delegator.delegate :method_name`을 호출하여 메서드 위임을 명시적으로 추가할 수 있다.

다음 속에 있을 때 위임 범위 바인딩을 갖는다:

* 톱레벨 바인딩, `require "sinatra"`를 한 경우
* `Sinatra::Delegator` 믹스인으로 확장된 객체

직접 코드를 살펴보길 바란다: 
[Sinatra::Delegator 믹스인](https://github.com/sinatra/sinatra/blob/ca06364/lib/sinatra/base.rb#L1609-1633)
코드는 [메인 객체를 확장한 것](https://github.com/sinatra/sinatra/blob/ca06364/lib/sinatra/main.rb#L28-30)이다.

## 명령행(Command Line)

Sinatra 애플리케이션은 직접 실행할 수 있다:

```ruby
ruby myapp.rb [-h] [-x] [-e ENVIRONMENT] [-p PORT] [-o HOST] [-s HANDLER]
```

옵션들:

```
-h # 도움말
-p # 포트 설정 (기본값은 4567)
-o # 호스트 설정 (기본값은 0.0.0.0)
-e # 환경 설정 (기본값은 development)
-s # rack 서버/핸들러 지정 (기본값은 thin)
-x # mutex 잠금 켜기 (기본값은 off)
```

## 요구사항(Requirement)

다음의 루비 버전은 공식적으로 지원한다:

<dl>
  <dt> Ruby 1.8.7 </dt>
  <dd>1.8.7은 완전하게 지원되지만, 꼭 그래야할 특별한 이유가 없다면, 
1.9.2로 업그레이드하거나 또는 JRuby나 Rubinius로 전환할 것을 권장한다.
1.8.7에 대한 지원은 Sinatra 2.0과 Ruby 2.0 이전에는 중단되지 않을 것이다.
또한 그때도, 우리는 계속 지원할 것이다.
<b>Ruby 1.8.6은 더이상 지원되지 않는다.</b>
만약 1.8.6으로 실행하려 한다면, Sinatra 1.2로 다운그레이드하라.
Sinatra 1.4.0이 릴리스될 때 까지는 버그 픽스를 받을 수 있을 것이다.

</dd>
  <dt> Ruby 1.9.2 </dt>
  <dd>1.9.2는 완전하게 지원되면 권장된다. Radius와 Maraby는 현재 1.9와 호환되지 않음에 유의하라.
1.9.2p0은, Sinatra를 실행했을 때 세그먼트 오류가 발생한다고 알려져 있으니 사용하지 말라.
Ruby 1.9.4/2.0 릴리스까지는 적어도 지원을 계속할 것이며,
최신 1.9 릴리스에 대한 지원은 Ruby 코어팀이 지원하고 있는 한 계속 지원할 것이다.

</dd>
  <dt> Ruby 1.9.3 </dt>
  <dd>1.9.3은 완전하게 지원된다. 그렇지만 프로덕션에서의 사용은
보다 상위의 패치 레벨이 릴리스될 때까지 기다리길 권장한다(현재는 p0). 
이전 버전에서 1.9.3으로 전환할 경우 모든 세션이 무효화된다는 점을 유의하라.

</dd>
  <dt> Rubinius </dt>
  <dd>Rubinius는 공식적으로 지원되며 (Rubinius >= 1.2.4), 모든 템플릿 언어를 포함한 모든 것들이 작동한다.
조만간 출시될 2.0 릴리스 역시 지원할 것이다.

</dd>
  <dt> JRuby </dt>
  <dd>JRuby는 공식적으로 지원된다 (JRuby >= 1.6.5). 서드 파티 템플릿 라이브러리와의 문제는 알려진 바 없지만,
만약 JRuby를 사용하기로 했다면, JRuby rack 핸들러를 찾아보길 바란다.
Thin 웹 서버는 JRuby에서 완전하게 지원되지 않는다.
JRuby의 C 확장 지원은 아직 실험 단계이며, RDiscount, Redcarpet 및 RedCloth가 현재
이 영향을 받는다.
</dd>
</dl>

또한 우리는 새로 나오는 루비 버전을 주시한다.

다음 루비 구현체들은 공식적으로 지원하지 않지만 
여전히 Sinatra를 실행할 수 있는 것으로 알려져 있다:

* JRuby와 Rubinius 예전 버전
* Ruby Enterprise Edition
* MacRuby, Maglev, IronRuby
* Ruby 1.9.0 및 1.9.1 (그러나 이 버전들은 사용하지 말 것을 권함)

공식적으로 지원하지 않는다는 것의 의미는 무언가가 그쪽에서만 잘못되고
지원되는 플랫폼에서는 그러지 않을 경우, 우리의 문제가 아니라 그쪽의 문제로 간주한다는 뜻이다.

또한 우리는 CI를 ruby-head (곧 나올 2.0.0) 과 1.9.4 브랜치에 맞춰 실행하지만,
계속해서 변하고 있기 때문에 아무 것도 보장할 수는 없다. 
1.9.4p0와 2.0.0p0가 지원되길 기대한다.

Sinatra는 선택한 루비 구현체가 지원하는 어떠한 운영체제에서도 작동해야 한다.

현재 Cardinal, SmallRuby, BlueRuby 또는 1.8.7 이전의 루비 버전에서는 
Sinatra를 실행할 수 없을 것이다.

## 최신(The Bleeding Edge)

Sinatra의 가장 최근 코드를 사용하고자 한다면, 
여러분 애플리케이션을 마스터 브랜치에 맞춰 실행하면 되지만, 덜 안정적일 것임에 분명하다.

또한 우리는 가끔 사전배포(prerelease) 젬을 푸시하기 때문에, 다음과 같이 할 수 있다

```ruby
gem install sinatra --pre
```

최신 기능들을 얻기 위해선

### Bundler를 사용하여

여러분 애플리케이션을 최신 Sinatra로 실행하고자 한다면, 
[Bundler](http://gembundler.com/)를 사용할 것을 권장한다.

우선, 아직 설치하지 않았다면 bundler를 설치한다:

```ruby
gem install bundler
```

그런 다음, 프로젝트 디렉터리에서, `Gemfile`을 하나 만든다:

```ruby
source :rubygems
gem 'sinatra', :git => "git://github.com/sinatra/sinatra.git"

# 다른 의존관계들
gem 'haml'# 예를 들어, haml을 사용한다면
gem 'activerecord', '~> 3.0'  # 아마도 ActiveRecord 3.x도 필요할 것
```

이 속에 애플리케이션의 모든 의존관계를 나열해야 함에 유의하자.
그렇지만, Sinatra가 직접적인 의존관계에 있는 것들 (Rack과 Tilt)은 
Bundler가 자동으로 추출하여 추가할 것이다.

이제 여러분은 다음과 같이 앱을 실행할 수 있다:

```ruby
bundle exec ruby myapp.rb
```

### 직접 하기(Roll Your Own)

로컬 클론(clone)을 생성한 다음 `$LOAD_PATH`에 `sinatra/lib` 디렉터리를 주고
여러분 앱을 실행한다:

```ruby
cd myapp
git clone git://github.com/sinatra/sinatra.git
ruby -Isinatra/lib myapp.rb
```

이후에 Sinatra 소스를 업데이트하려면:

```ruby
cd myapp/sinatra
git pull
```

### 전역으로 설치(Install Globally)

젬을 직접 빌드할 수 있다:

```ruby
git clone git://github.com/sinatra/sinatra.git
cd sinatra
rake sinatra.gemspec
rake install
```

만약 젬을 루트로 설치한다면, 마지막 단계는 다음과 같이 해야 한다

```ruby
sudo rake install
```

## 버저닝(Versioning)

Sinatra는 [시맨틱 버저닝Semantic Versioning](http://semver.org/)을 준수한다.
SemVer 및 SemVerTag 둘 다 해당된.

## 더 읽을 거리(Further Reading)

* [프로젝트 웹사이트](http://www.sinatrarb.com/) - 추가 문서들, 뉴스, 그리고 다른 리소스들에 대한 링크.
* [기여하기](http://www.sinatrarb.com/contributing) - 버그를 찾았나요? 도움이 필요한가요? 패치를 하셨나요?
* [이슈 트래커](http://github.com/sinatra/sinatra/issues)
* [트위터](http://twitter.com/sinatra)
* [Mailing List](http://groups.google.com/group/sinatrarb/topics)
* [IRC: #sinatra](irc://chat.freenode.net/#sinatra) http://freenode.net 
* [Sinatra Book](http://sinatra-book.gittr.com) Cookbook 튜토리얼
* [Sinatra Recipes](http://recipes.sinatrarb.com/) 커뮤니티가 만드는 레시피
* http://rubydoc.info에 있는 [최종 릴리스](http://rubydoc.info/gems/sinatra)
또는 [current HEAD](http://rubydoc.info/github/sinatra/sinatra)에 대한 API 문서
* [CI server](http://travis-ci.org/sinatra/sinatra)
