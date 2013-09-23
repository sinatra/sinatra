# Sinatra

*注）
本文書は英語から翻訳したものであり、その内容が最新でない場合もあります。最新の情報はオリジナルの英語版を参照して下さい。*

[DSL](http://ja.wikipedia.org/wiki/ドメイン固有言語)です。

    # myapp.rb
    require 'sinatra'
    get '/' do
      'Hello world!'
    end

gemをインストールして動かしてみる。

    gem install sinatra
    ruby myapp.rb

[localhost:4567](http://localhost:4567) を見る。

## ルート

Sinatraでは、ルートはHTTPメソッドとURLマッチングパターンがペアになっています。
ルートはブロックに結び付けられています。

``` ruby
get '/' do
  .. 何か見せる ..
end

post '/' do
  .. 何か生成する ..
end

put '/' do
  .. 何か更新する ..
end

patch '/' do
  .. 何か修正する ..
end

delete '/' do
  .. 何か削除する ..
end

options '/' do
  .. 何か満たす ..
end

link '/' do
  .. 何かリンクを張る ..
end

unlink '/' do
  .. 何かアンリンクする ..
end
```

ルートは定義された順番にマッチします。
リクエストに最初にマッチしたルートが呼び出されます。

ルートのパターンは名前付きパラメータを含むことができ、
`params`ハッシュで取得できます。

``` ruby
get '/hello/:name' do
  # "GET /hello/foo" と "GET /hello/bar" にマッチ
  # params[:name] は 'foo' か 'bar'
  "Hello #{params[:name]}!"
end
```

また、ブロックパラメータで名前付きパラメータにアクセスすることもできます。

``` ruby
get '/hello/:name' do |n|
  # "GET /hello/foo" と "GET /hello/bar" にマッチ
  # params[:name] は 'foo' か 'bar'
  # n が params[:name] を保持
  "Hello #{n}!"
end
```

ルートパターンはsplat(またはワイルドカード)を含むこともでき、
`params[:splat]` で取得できます。

``` ruby
get '/say/*/to/*' do
  # /say/hello/to/world にマッチ
  params[:splat] # => ["hello", "world"]
end

get '/download/*.*' do
  # /download/path/to/file.xml にマッチ
  params[:splat] # => ["path/to/file", "xml"]
end
```

ブロックパラーメータを使用した場合:

``` ruby
get '/download/*.*' do |path, ext|
  [path, ext] # => ["path/to/file", "xml"]
end
```

正規表現を使用した場合:

``` ruby
get %r{/hello/([\w]+)} do
  "Hello, #{params[:captures].first}!"
end
```

ブロックパラーメータを使用した場合:

``` ruby
get %r{/hello/([\w]+)} do |c|
  "Hello, #{c}!"
end
```

オプショナルパラメーターを使用した場合:

``` ruby
get '/posts.?:format?' do
  # "GET /posts" と "GET /posts.json", "GET /posts.xml" の拡張子などにマッチ
end
```

ところで、ディレクトリトラバーサル保護機能を無効にしないと（下記参照）、
ルートにマッチする前にリクエストパスが修正される可能性があります。

### 条件

ルートにはユーザエージェントのようなさまざまな条件を含めることができます。

    get '/foo', :agent => /Songbird (\d\.\d)[\d\/]*?/ do
      "You're using Songbird version #{params[:agent][0]}"
    end

    get '/foo' do
      # Matches non-songbird browsers
    end

ほかに`host_name`と`provides`条件が利用可能です:

    get '/', :host_name => /^admin\./ do
      "Admin Area, Access denied!"
    end

    get '/', :provides => 'html' do
      haml :index
    end

    get '/', :provides => ['rss', 'atom', 'xml'] do
      builder :feed
    end

独自の条件を定義することも簡単にできます:

    set(:probability) { |value| condition { rand <= value } }

    get '/win_a_car', :probability => 0.1 do
      "You won!"
    end

    get '/win_a_car' do
      "Sorry, you lost."
    end

### 戻り値

ルートブロックの戻り値は、HTTPクライアントまたはRackスタックでの次のミドルウェアに渡されるレスポンスボディを決定します。

これは大抵の場合、上の例のように文字列ですが、それ以外の値も使用することができます。

Rackレスポンス、Rackボディオブジェクト、HTTPステータスコードのいずれかとして
妥当なオブジェクトであればどのようなオブジェクトでも返すことができます:

-   3要素の配列:
    `[ステータス(Fixnum), ヘッダ(Hash), レスポンスボディ(#eachに応答する)]`

-   2要素の配列:
    `[ステータス(Fixnum), レスポンスボディ(#eachに応答する)]`

-   `#each`に応答し、与えられたブロックに文字列を渡すオブジェクト

-   ステータスコードを表現するFixnum

そのように、例えばストリーミングの例を簡単に実装することができます:

    class Stream
      def each
        100.times { |i| yield "#{i}\n" }
      end
    end

    get('/') { Stream.new }

## 静的ファイル

静的ファイルは`./public`ディレクトリから配信されます。
`:public_folder`オプションを指定することで別の場所を指定することができます。

    set :public_folder, File.dirname(__FILE__) + '/static'

注意: この静的ファイル用のディレクトリ名はURL中に含まれません。
例えば、`./public/css/style.css`は`http://example.com/css/style.css`でアクセスできます。

## ビュー / テンプレート

テンプレートは`./views`ディレクトリ下に配置されています。
他のディレクトリを使用する場合の例:

    set :views, File.dirname(__FILE__) + '/templates'

テンプレートはシンボルを使用して参照させることを覚えておいて下さい。
サブデレクトリでもこの場合は`:'subdir/template'`のようにします。
レンダリングメソッドは文字列が渡されると、そのまま文字列を出力します。

### Haml テンプレート

hamlを使うにはhamlライブラリが必要です:

    # hamlを読み込みます
    require 'haml'

    get '/' do
      haml :index
    end

`./views/index.haml`を表示します。

[Haml’s
options](http://haml.info/docs/yardoc/file.HAML_REFERENCE.html#options)
はSinatraの設定でグローバルに設定することができます。 [Options and
Configurations](http://www.sinatrarb.com/configuration.html),
を参照してそれぞれ設定を上書きして下さい。

    set :haml, {:format => :html5 } # デフォルトのフォーマットは:xhtml

    get '/' do
      haml :index, :haml_options => {:format => :html4 } # 上書き
    end

### Erb テンプレート

    # erbを読み込みます
    require 'erb'

    get '/' do
      erb :index
    end

`./views/index.erb`を表示します。

### Erubis

erubisテンプレートを表示するには、erubisライブラリが必要です:

    # erubisを読み込みます
    require 'erubis'

    get '/' do
      erubis :index
    end

`./views/index.erubis`を表示します。

### Builder テンプレート

builderを使うにはbuilderライブラリが必要です:

    # builderを読み込みます
    require 'builder'

    get '/' do
      builder :index
    end

`./views/index.builder`を表示します。

### 鋸 テンプレート

鋸を使うには鋸ライブラリが必要です:

    # 鋸を読み込みます
    require 'nokogiri'

    get '/' do
      nokogiri :index
    end

`./views/index.nokogiri`を表示します。

### Sass テンプレート

Sassテンプレートを使うにはsassライブラリが必要です:

    # hamlかsassを読み込みます
    require 'sass'

    get '/stylesheet.css' do
      sass :stylesheet
    end

`./views/stylesheet.sass`を表示します。

[Sass’
options](http://sass-lang.com/docs/yardoc/file.SASS_REFERENCE.html#options)
はSinatraの設定でグローバルに設定することができます。 see [Options and
Configurations](http://www.sinatrarb.com/configuration.html),
を参照してそれぞれ設定を上書きして下さい。

    set :sass, {:style => :compact } # デフォルトのSass styleは :nested

    get '/stylesheet.css' do
      sass :stylesheet, :sass_options => {:style => :expanded } # 上書き
    end

### Scss テンプレート

Scssテンプレートを使うにはsassライブラリが必要です:

    # hamlかsassを読み込みます
    require 'sass'

    get '/stylesheet.css' do
      scss :stylesheet
    end

`./views/stylesheet.scss`を表示します。

[Sass’
options](http://sass-lang.com/docs/yardoc/file.SASS_REFERENCE.html#options)
はSinatraの設定でグローバルに設定することができます。 see [Options and
Configurations](http://www.sinatrarb.com/configuration.html),
を参照してそれぞれ設定を上書きして下さい。

    set :scss, :style => :compact # デフォルトのScss styleは:nested

    get '/stylesheet.css' do
      scss :stylesheet, :style => :expanded # 上書き
    end

### Less テンプレート

Lessテンプレートを使うにはlessライブラリが必要です:

    # lessを読み込みます
    require 'less'

    get '/stylesheet.css' do
      less :stylesheet
    end

`./views/stylesheet.less`を表示します。

### Liquid テンプレート

Liquidテンプレートを使うにはliquidライブラリが必要です:

    # liquidを読み込みます
    require 'liquid'

    get '/' do
      liquid :index
    end

`./views/index.liquid`を表示します。

LiquidテンプレートからRubyのメソッド(`yield`を除く)を呼び出すことができないため、
ほぼ全ての場合にlocalsを指定する必要があるでしょう:

    liquid :index, :locals => { :key => 'value' }

### Markdown テンプレート

Markdownテンプレートを使うにはrdiscountライブラリが必要です:

    # rdiscountを読み込みます
    require "rdiscount"

    get '/' do
      markdown :index
    end

`./views/index.markdown`を表示します。(`md`と`mkd`も妥当な拡張子です)

markdownからメソッドを呼び出すことも、localsに変数を渡すこともできません。
それゆえ、他のレンダリングエンジンとの組み合わせで使うのが普通です:

    erb :overview, :locals => { :text => markdown(:introduction) }

他のテンプレートからmarkdownメソッドを呼び出してもよいことに注意してください:

    %h1 Hello From Haml!
    %p= markdown(:greetings)

### Textile テンプレート

Textileテンプレートを使うにはRedClothライブラリが必要です:

    # redclothを読み込みます
    require "redcloth"

    get '/' do
      textile :index
    end

`./views/index.textile`を表示します。

textileからメソッドを呼び出すことも、localsに変数を渡すこともできません。
それゆえ、他のレンダリングエンジンとの組み合わせで使うのが普通です:

    erb :overview, :locals => { :text => textile(:introduction) }

他のテンプレートからtextileメソッドを呼び出してもよいことに注意してください:

    %h1 Hello From Haml!
    %p= textile(:greetings)

### RDoc テンプレート

RDocテンプレートを使うにはRDocライブラリが必要です:

    # rdoc/markup/to_htmlを読み込みます
    require "rdoc"
    require "rdoc/markup/to_html"

    get '/' do
      rdoc :index
    end

`./views/index.rdoc`を表示します。

rdocからメソッドを呼び出すことも、localsに変数を渡すこともできません。
それゆえ、他のレンダリングエンジンとの組み合わせで使うのが普通です:

    erb :overview, :locals => { :text => rdoc(:introduction) }

他のテンプレートからrdocメソッドを呼び出してもよいことに注意してください:

    %h1 Hello From Haml!
    %p= rdoc(:greetings)

### Radius テンプレート

Radiusテンプレートを使うにはradiusライブラリが必要です:

    # radiusを読み込みます
    require 'radius'

    get '/' do
      radius :index
    end

`./views/index.radius`を表示します。

RadiusテンプレートからRubyのメソッド(`yield`を除く)を呼び出すことができないため、
ほぼ全ての場合にlocalsを指定する必要があるでしょう:

    radius :index, :locals => { :key => 'value' }

### Markaby テンプレート

Markabyテンプレートを使うにはmarkabyライブラリが必要です:

    # markabyを読み込みます
    require 'markaby'

    get '/' do
      markaby :index
    end

`./views/index.mab`を表示します。

### RABL テンプレート

RABLテンプレートを使うにはrablライブラリが必要です:

    # rablを読み込みます
    require 'rabl'

    get '/' do
      rabl :index
    end

`./views/index.rabl`を表示します。

### Slim テンプレート

Slimテンプレートを使うにはslimライブラリが必要です:

    # slimを読み込みます
    require 'slim'

    get '/' do
      slim :index
    end

`./views/index.slim`を表示します。

### Creole テンプレート

Creoleテンプレートを使うにはcreoleライブラリが必要です:

    # creoleを読み込みます
    require 'creole'

    get '/' do
      creole :index
    end

`./views/index.creole`を表示します。

### CoffeeScript テンプレート

CoffeeScriptテンプレートを表示するにはcoffee-scriptライブラリと\`coffee\`バイナリが必要です:

    # coffee-scriptを読み込みます
    require 'coffee-script'

    get '/application.js' do
      coffee :application
    end

`./views/application.coffee`を表示します。

### インラインテンプレート

    get '/' do
      haml '%div.title Hello World'
    end

文字列をテンプレートとして表示します。

### テンプレート内で変数にアクセスする

テンプレートはルートハンドラと同じコンテキストの中で評価されます。.
ルートハンドラでセットされたインスタンス変数は
テンプレート内で直接使うことができます。

    get '/:id' do
      @foo = Foo.find(params[:id])
      haml '%h1= @foo.name'
    end

ローカル変数を明示的に定義することもできます。

    get '/:id' do
      foo = Foo.find(params[:id])
      haml '%h1= foo.name', :locals => { :foo => foo }
    end

このやり方は他のテンプレート内で部分テンプレートとして表示する時に典型的に使用されます。

### ファイル内テンプレート

テンプレートはソースファイルの最後で定義することもできます。

    require 'rubygems'
    require 'sinatra'

    get '/' do
      haml :index
    end

    __END__

    @@ layout
    %html
      = yield

    @@ index
    %div.title Hello world!!!!!

注意:
sinatraをrequireするファイル内で定義されたファイル内テンプレートは自動的に読み込まれます。
他のファイルで定義されているテンプレートを使うには
`enable :inline_templates`を明示的に呼んでください。

### 名前付きテンプレート

テンプレートはトップレベルの`template`メソッドで定義することができます。

    template :layout do
      "%html\n  =yield\n"
    end

    template :index do
      '%div.title Hello World!'
    end

    get '/' do
      haml :index
    end

「layout」というテンプレートが存在する場合、そのテンプレートファイルは他のテンプレートが
表示される度に使用されます。`:layout => false`することでlayoutsを無効にできます。

    get '/' do
      haml :index, :layout => !request.xhr?
    end

## ヘルパー

トップレベルの`helpers`を使用してルートハンドラやテンプレートで使うヘルパメソッドを
定義できます。

    helpers do
      def bar(name)
        "#{name}bar"
      end
    end

    get '/:name' do
      bar(params[:name])
    end

## フィルタ

beforeフィルタはリクエストされたコンテキストを実行する前に評価され、
リクエストとレスポンスを変更することができます。フィルタ内でセットされた
インスタンス変数はルーティングとテンプレートで使用できます。

    before do
      @note = 'Hi!'
      request.path_info = '/foo/bar/baz'
    end

    get '/foo/*' do
      @note #=> 'Hi!'
      params[:splat] #=> 'bar/baz'
    end

afterフィルタは同じコンテキストにあるリクエストの後に評価され、
同じくリクエストとレスポンスを変更することができます。
beforeフィルタとルートで設定されたインスタンス変数は、
afterフィルタからアクセスすることができます:

    after do
      puts response.status
    end

フィルタにはオプションとしてパターンを渡すことができ、
この場合はリクエストのパスがパターンにマッチした場合のみフィルタが評価されます:

    before '/protected/*' do
      authenticate!
    end

    after '/create/:slug' do |slug|
      session[:last_slug] = slug
    end

## 強制終了

ルートかbeforeフィルタ内で直ちに実行を終了する方法:

    halt

ステータスを指定することができます:

    halt 410

body部を指定することもできます …

    halt 'ここにbodyを書く'

ステータスとbody部を指定する …

    halt 401, '立ち去れ!'

ヘッダを指定:

    halt 402, {'Content-Type' => 'text/plain'}, 'リベンジ'

## パッシング(Passing)

ルートは`pass`を使って次のルートに飛ばすことができます:

    get '/guess/:who' do
      pass unless params[:who] == 'Frank'
      "見つかっちゃった!"
    end

    get '/guess/*' do
      "はずれです!"
    end

ルートブロックからすぐに抜け出し、次にマッチするルートを実行します。
マッチするルートが見当たらない場合は404が返されます。

## リクエストオブジェクトへのアクセス

受信するリクエストオブジェクトは、\`request\`メソッドを通じてリクエストレベル(フィルタ、ルート、エラーハンドラ)からアクセスすることができます:

    # アプリケーションが http://example.com/example で動作している場合
    get '/foo' do
      request.body              # クライアントによって送信されたリクエストボディ(下記参照)
      request.scheme            # "http"
      request.script_name       # "/example"
      request.path_info         # "/foo"
      request.port              # 80
      request.request_method    # "GET"
      request.query_string      # ""
      request.content_length    # request.bodyの長さ
      request.media_type        # request.bodyのメディアタイプ
      request.host              # "example.com"
      request.get?              # true (他の動詞についても同様のメソッドあり)
      request.form_data?        # false
      request["SOME_HEADER"]    # SOME_HEADERヘッダの値
      request.referer           # クライアントのリファラまたは'/'
      request.user_agent        # ユーザエージェント (:agent 条件によって使用される)
      request.cookies           # ブラウザクッキーのハッシュ
      request.xhr?              # Ajaxリクエストかどうか
      request.url               # "http://example.com/example/foo"
      request.path              # "/example/foo"
      request.ip                # クライアントのIPアドレス
      request.secure?           # false
      request.env               # Rackによって渡された生のenvハッシュ
    end

`script_name`や`path_info`などのオプションは次のように利用することもできます:

    before { request.path_info = "/" }

    get "/" do
      "全てのリクエストはここに来る"
    end

`request.body`はIOまたはStringIOのオブジェクトです:

    post "/api" do
      request.body.rewind  # 既に読まれているときのため
      data = JSON.parse request.body.read
      "Hello #{data['name']}!"
    end

## 設定

どの環境でも起動時に１回だけ実行されます。

    configure do
      ...
    end

環境(RACK\_ENV環境変数)が`:production`に設定されている時だけ実行する方法:

    configure :production do
      ...
    end

環境が`:production`か`:test`の場合に設定する方法:

    configure :production, :test do
      ...
    end

## エラーハンドリング

エラーハンドラーはルートコンテキストとbeforeフィルタ内で実行します。
`haml`、`erb`、`halt`などを使うこともできます。

### Not Found

`Sinatra::NotFound`が起きた時か レスポンスのステータスコードが
404の時に`not_found`ハンドラーが発動します。

    not_found do
      'ファイルが存在しません'
    end

### エラー

`error`
ハンドラーはルートブロックかbeforeフィルタ内で例外が発生した時はいつでも発動します。
例外オブジェクトはRack変数`sinatra.error`から取得できます。

    error do
      'エラーが発生しました。 - ' + env['sinatra.error'].name
    end

エラーをカスタマイズする場合は、

    error MyCustomError do
      'エラーメッセージ...' + env['sinatra.error'].message
    end

と書いておいて,下記のように呼び出します。

    get '/' do
      raise MyCustomError, '何かがまずかったようです'
    end

そうするとこうなります:

    エラーメッセージ... 何かがまずかったようです

あるいは、ステータスコードに対応するエラーハンドラを設定することもできます:

    error 403 do
      'Access forbidden'
    end

    get '/secret' do
      403
    end

範囲指定もできます:

    error 400..510 do
      'Boom'
    end

開発環境として実行している場合、Sinatraは特別な`not_found`と`error`ハンドラーを
インストールしています。

## MIMEタイプ

`send_file`か静的ファイルを使う時、Sinatraが理解でいないMIMEタイプがある場合があります。
その時は `mime_type` を使ってファイル拡張子毎に登録して下さい。

    mime_type :foo, 'text/foo'

これはcontent\_typeヘルパで利用することができます:

    content_type :foo

## Rackミドルウェア

[SinatraはRack](http://rack.rubyforge.org/)フレームワーク用の
最小限の標準インターフェース
上で動作しています。Rack中でもアプリケーションデベロッパー
向けに一番興味深い機能はミドルウェア(サーバとアプリケーション間に介在し、モニタリング、HTTPリクエストとレスポンス
の手動操作ができるなど、一般的な機能のいろいろなことを提供するもの)をサポートすることです。

Sinatraではトップレベルの`use`
メソッドを使ってRackにパイプラインを構築します。

    require 'sinatra'
    require 'my_custom_middleware'

    use Rack::Lint
    use MyCustomMiddleware

    get '/hello' do
      'Hello World'
    end

`use`
[Rack::Builder](http://rack.rubyforge.org/doc/classes/Rack/Builder.html)
DSLで定義されていることと全て一致します。 例えば `use`
メソッドはブロック構文のように複数の引数を受け取ることができます。

    use Rack::Auth::Basic do |username, password|
      username == 'admin' && password == 'secret'
    end

Rackはログ、デバッギング、URLルーティング、認証、セッションなどいろいろな機能を備えた標準的ミドルウェアです。
Sinatraはその多くのコンポーネントを自動で使うよう基本設定されているため、`use`で明示的に指定する必要はありません。

## テスト

SinatraでのテストはRack-basedのテストライブラリかフレームワークを使って書くことができます。
[Rack::Test](http://gitrdoc.com/brynary/rack-test)
をおすすめします。やり方:

    require 'my_sinatra_app'
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
        assert_equal "あなたはSongbirdを使ってますね!", last_response.body
      end
    end

注意: ビルトインのSinatra::TestモジュールとSinatra::TestHarnessクラスは
0.9.2リリース以降、廃止予定になっています。

## Sinatra::Base - ミドルウェア、ライブラリ、 モジュラーアプリ

トップレベル(グローバル領域)上でいろいろ定義していくのは軽量アプリならうまくいきますが、
RackミドルウェアやRails metal、サーバのコンポーネントを含んだシンプルな
ライブラリやSinatraの拡張プログラムを考慮するような場合はそうとは限りません。
トップレベルのDSLがネームスペースを汚染したり、設定を変えてしまうこと(例:./publicや./view)がありえます。
そこでSinatra::Baseの出番です。

    require 'sinatra/base'

    class MyApp < Sinatra::Base
      set :sessions, true
      set :foo, 'bar'

      get '/' do
        'Hello world!'
      end
    end

このMyAppは独立したRackコンポーネントで、RackミドルウェアやRackアプリケーション
Rails metalとして使用することができます。`config.ru`ファイル内で `use`
か、または `run`
でこのクラスを指定するか、ライブラリとしてサーバコンポーネントをコントロールします。

    MyApp.run! :host => 'localhost', :port => 9090

Sinatra::Baseのサブクラスで使えるメソッドはトップレベルのDSLを経由して確実に使うことができます。
ほとんどのトップレベルで記述されたアプリは、以下の２点を修正することでSinatra::Baseコンポーネントに変えることができます。

-   `sinatra`の代わりに`sinatra/base`を読み込む

(そうしない場合、SinatraのDSLメソッドの全てがメインネームスペースにインポートされます)

-   ルート、エラーハンドラー、フィルター、オプションをSinatra::Baseのサブクラスに書く

`Sinatra::Base`
はまっさらです。ビルトインサーバを含む、ほとんどのオプションがデフォルト
で無効になっています。オプション詳細については[Options and
Configuration](http://sinatra.github.com/configuration.html)
をご覧下さい。

補足:
SinatraのトップレベルDSLはシンプルな委譲(delgation)システムで実装されています。
`Sinatra::Application`クラス(Sinatra::Baseの特別なサブクラス)は、トップレベルに送られる
:get、 :put、 :post、:delete、 :before、:error、:not\_found、
:configure、:set messagesのこれら 全てを受け取ります。
詳細を閲覧されたい方はこちら(英語): [Sinatra::Delegator
mixin](http://github.com/sinatra/sinatra/blob/master/lib/sinatra/base.rb#L1064)
[included into the main
namespace](http://github.com/sinatra/sinatra/blob/master/lib/sinatra/main.rb#L25).

### Sinatraをミドルウェアとして利用する

Sinatraは他のRackミドルウェアを利用することができるだけでなく、
全てのSinatraアプリケーションは、それ自体ミドルウェアとして別のRackエンドポイントの前に追加することが可能です。

このエンドポイントには、別のSinatraアプリケーションまたは他のRackベースのアプリケーション(Rails/Ramaze/Camping/…)が用いられるでしょう。

    require 'sinatra/base'

    class LoginScreen < Sinatra::Base
      enable :sessions

      get('/login') { haml :login }

      post('/login') do
        if params[:name] = 'admin' and params[:password] = 'admin'
          session['user_name'] = params[:name]
        else
          redirect '/login'
        end
      end
    end

    class MyApp < Sinatra::Base
      # middleware will run before filters
      use LoginScreen

      before do
        unless session['user_name']
          halt "Access denied, please <a href='/login'>login</a>."
        end
      end

      get('/') { "Hello #{session['user_name']}." }
    end

## スコープとバインディング

現在のスコープはどのメソッドや変数が利用可能かを決定します。

### アプリケーション/クラスのスコープ

全てのSinatraアプリケーションはSinatra::Baseのサブクラスに相当します。
もしトップレベルDSLを利用しているならば(`require 'sinatra'`)このクラスはSinatra::Applicationであり、
そうでなければ、あなたが明示的に作成したサブクラスです。
クラスレベルでは\`get\`や\`before\`のようなメソッドを持っています。
しかし\`request\`オブジェクトや\`session\`には、全てのリクエストのために1つのアプリケーションクラスが存在するためアクセスできません。

\`set\`によって作られたオプションはクラスレベルのメソッドです:

    class MyApp < Sinatra::Base
      # Hey, I'm in the application scope!
      set :foo, 42
      foo # => 42

      get '/foo' do
        # Hey, I'm no longer in the application scope!
      end
    end

次の場所ではアプリケーションスコープバインディングを持ちます:

-   アプリケーションのクラス本体

-   拡張によって定義されたメソッド

-   \`helpers\`に渡されたブロック

-   \`set\`の値として使われるProcまたはブロック

このスコープオブジェクト(クラス)は次のように利用できます:

-   configureブロックに渡されたオブジェクト経由(`configure { |c| ... }`)

-   リクエストスコープの中での\`settings\`

### リクエスト/インスタンスのスコープ

やってくるリクエストごとに、あなたのアプリケーションクラスの新しいインスタンスが作成され、全てのハンドラブロックがそのスコープで実行されます。
このスコープの内側からは\`request\`や\`session\`オブジェクトにアクセスすることができ、\`erb\`や\`haml\`のような表示メソッドを呼び出すことができます。
リクエストスコープの内側からは、\`settings\`ヘルパによってアプリケーションスコープにアクセスすることができます。

    class MyApp < Sinatra::Base
      # Hey, I'm in the application scope!
      get '/define_route/:name' do
        # Request scope for '/define_route/:name'
        @value = 42

        settings.get("/#{params[:name]}") do
          # Request scope for "/#{params[:name]}"
          @value # => nil (not the same request)
        end

        "Route defined!"
      end
    end

次の場所ではリクエストスコープバインディングを持ちます:

-   get/head/post/put/delete ブロック

-   before/after フィルタ

-   helper メソッド

-   テンプレート/ビュー

### デリゲートスコープ

デリゲートスコープは、単にクラススコープにメソッドを転送します。
しかしながら、クラスのバインディングを持っていないため、クラススコープと全く同じふるまいをするわけではありません:
委譲すると明示的に示されたメソッドのみが利用可能であり、またクラススコープと変数/状態を共有することはできません(注:
異なった\`self\`を持っています)。
`Sinatra::Delegator.delegate :method_name`を呼び出すことによってデリゲートするメソッドを明示的に追加することができます。

次の場所ではデリゲートスコープを持ちます:

-   もし`require "sinatra"`しているならば、トップレベルバインディング

-   \`Sinatra::Delegator\` mixinでextendされたオブジェクト

コードをご覧ください: ここでは [Sinatra::Delegator
mixin](http://github.com/sinatra/sinatra/blob/ceac46f0bc129a6e994a06100aa854f606fe5992/lib/sinatra/base.rb#L1128)
は[main
名前空間にincludeされています](http://github.com/sinatra/sinatra/blob/ceac46f0bc129a6e994a06100aa854f606fe5992/lib/sinatra/main.rb#L28).

## コマンドライン

Sinatraアプリケーションは直接実行できます。

    ruby myapp.rb [-h] [-x] [-e ENVIRONMENT] [-p PORT] [-o HOST] [-s HANDLER]

オプション:

    -h # ヘルプ
    -p # ポート指定(デフォルトは4567)
    -o # ホスト指定(デフォルトは0.0.0.0)
    -e # 環境を指定 (デフォルトはdevelopment)
    -s # rackserver/handlerを指定 (デフォルトはthin)
    -x # mutex lockを付ける (デフォルトはoff)

## 最新開発版について

Sinatraの開発版を使いたい場合は、ローカルに開発版を落として、
`LOAD_PATH`の`sinatra/lib`ディレクトリを指定して実行して下さい。

    cd myapp
    git clone git://github.com/sinatra/sinatra.git
    ruby -Isinatra/lib myapp.rb

`sinatra/lib`ディレクトリをアプリケーションの`LOAD_PATH`に追加する方法もあります。

    $LOAD_PATH.unshift File.dirname(__FILE__) + '/sinatra/lib'
    require 'rubygems'
    require 'sinatra'

    get '/about' do
      "今使ってるバージョンは" + Sinatra::VERSION
    end

Sinatraのソースを更新する方法:

    cd myproject/sinatra
    git pull

## その他

日本語サイト

-   [Greenbear Laboratory
    Rack日本語マニュアル](http://mono.kmc.gr.jp/~yhara/w/?RackReferenceJa)
    - Rackの日本語マニュアル

英語サイト

-   [プロジェクトサイト](http://sinatra.github.com/) - ドキュメント、
    ニュース、他のリソースへのリンクがあります。

-   [プロジェクトに参加(貢献)する](http://sinatra.github.com/contributing.html)
    - バグレポート パッチの送信、サポートなど

-   [Issue tracker](http://github.com/sinatra/sinatra/issues) -
    チケット管理とリリース計画

-   [Twitter](http://twitter.com/sinatra)

-   [メーリングリスト](http://groups.google.com/group/sinatrarb)

-   [IRC: \#sinatra](irc://chat.freenode.net/#sinatra) on
    [freenode.net](http://freenode.net)