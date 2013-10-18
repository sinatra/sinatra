# Sinatra

*Atenção: Este documento é apenas uma tradução da versão em inglês e
pode estar desatualizado.*

Alguns dos trechos de códigos a seguir utilizam caracteres UTF-8, então caso esteja utilizando uma versão de ruby inferior a `2.0.0` adicione o enconding no início de seus arquivos:

```ruby
# encoding: utf-8
```

Sinatra é uma [DSL](http://pt.wikipedia.org/wiki/Linguagem_de_domínio_específico) para
criar aplicações web em Ruby com o mínimo de esforço e rapidez:

``` ruby
# minha_app.rb
require 'sinatra'

get '/' do
  'Olá Mundo!'
end
```

Instale a gem:

``` shell
gem install sinatra
```

Em seguida execute:

``` shell
ruby minha_app.rb
```

Acesse: [localhost:4567](http://localhost:4567)

É recomendado também executar `gem install thin`. Caso esta gem esteja disponível, o
Sinatra irá utilizá-la.


## Rotas

No Sinatra, uma rota é um método HTTP emparelhado com um padrão de URL.
Cada rota possui um bloco de execução:

``` ruby
get '/' do
  .. mostrando alguma coisa ..
end

post '/' do
  .. criando alguma coisa ..
end

put '/' do
  .. atualizando alguma coisa ..
end

patch '/' do
  .. modificando alguma coisa ..
end

delete '/' do
  .. removendo alguma coisa ..
end

options '/' do
  .. estabelecendo alguma coisa ..
end
```

As rotas são interpretadas na ordem em que são definidas. A primeira
rota encontrada responde ao pedido.

Padrões de rota podem conter parâmetros nomeados, acessível através do
hash `params`:

``` ruby
get '/ola/:nome' do
  # corresponde a "GET /ola/foo" e "GET /ola/bar"
  # params[:nome] é 'foo' ou 'bar'
  "Olá #{params[:nome]}!"
end
```

Você também pode acessar parâmetros nomeados através dos parâmetros de
um bloco:

``` ruby
get '/ola/:nome' do |n|
  "Olá #{n}!"
end
```

Padrões de rota também podem conter parâmetros splat (wildcard),
acessível através do array `params[: splat]`:

``` ruby
get '/diga/*/para/*' do
  # corresponde a /diga/ola/para/mundo
  params[:splat] # => ["ola", "mundo"]
end

get '/download/*.*' do
  # corresponde a /download/pasta/do/arquivo.xml
  params[:splat] # => ["pasta/do/arquivo", "xml"]
end
```

Ou com parâmetros de um bloco:

``` ruby
get '/download/*.*' do |pasta, ext|
  [pasta, ext] # => ["pasta/do/arquivo", "xml"]
end
```

Rotas podem corresponder com expressões regulares:

``` ruby
get %r{/ola/([\w]+)} do
  "Olá, #{params[:captures].first}!"
end
```

Ou com parâmetros de um bloco:

``` ruby
get %r{/ola/([\w]+)} do |c|
  "Olá, #{c}!"
end
```

Padrões de rota podem contar com parâmetros opcionais:

``` ruby
get '/posts.?:formato?' do
  # corresponde a "GET /posts" e qualquer extensão "GET /posts.json", "GET /posts.xml", etc.
end
```

A propósito, a menos que você desative a proteção contra ataques (veja
abaixo), o caminho solicitado pode ser alterado antes de concluir a
comparação com as suas rotas.

### Condições

Rotas podem incluir uma variedade de condições, tal como o `user agent`:

``` ruby
get '/foo', :agent => /Songbird (\d\.\d)[\d\/]*?/ do
  "Você está usando o Songbird versão #{params[:agent][0]}"
end

get '/foo' do
  # Correspondente a navegadores que não sejam Songbird
end
```

Outras condições disponíveis são `host_name` e `provides`:

``` ruby
get '/', :host_name => /^admin\./ do
  "Área administrativa. Acesso negado!"
end

get '/', :provides => 'html' do
  haml :index
end

get '/', :provides => ['rss', 'atom', 'xml'] do
  builder :feed
end
```

Você pode facilmente definir suas próprias condições:

``` ruby
set(:probabilidade) { |valor| condition { rand <= valor } }

get '/ganha_um_carro', :probabilidade => 0.1 do
  "Você ganhou!"
end

get '/ganha_um_carro' do
  "Sinto muito, você perdeu."
end
```

Use splat, para uma condição que levam vários valores:

``` ruby
set(:auth) do |*roles|   # <- observe o splat aqui
  condition do
    unless logged_in? && roles.any? {|role| current_user.in_role? role }
      redirect "/login/", 303
    end
  end
end

get "/minha/conta/", :auth => [:usuario, :administrador] do
  "Detalhes da sua conta"
end

get "/apenas/administrador/", :auth => :administrador do
  "Apenas administradores são permitidos aqui!"
end
```

### Retorno de valores

O valor de retorno do bloco de uma rota determina pelo menos o corpo da
resposta passado para o cliente HTTP, ou pelo menos o próximo middleware
na pilha Rack. Frequentemente, isto é uma `string`, tal como nos
exemplos acima. Mas, outros valores também são aceitos.

Você pode retornar uma resposta válida ou um objeto para o Rack, sendo
eles de qualquer tipo de objeto que queira. Além disto, é possível
retornar um código de status HTTP.

-   Um array com três elementros: `[status (Fixnum), cabecalho (Hash),
    corpo da resposta (responde à #each)]`

-   Um array com dois elementros: `[status (Fixnum), corpo da resposta
    (responde à #each)]`

-   Um objeto que responda à `#each` sem passar nada, mas, sim, `strings`
    para um dado bloco

-   Um objeto `Fixnum` representando o código de status

Dessa forma, podemos implementar facilmente um exemplo de streaming:

``` ruby
class Stream
  def each
    100.times { |i| yield "#{i}\n" }
  end
end

get('/') { Stream.new }
```

Você também pode usar o método auxiliar `stream` (descrito abaixo) para
incorporar a lógica de streaming na rota.

### Custom Route Matchers

Como apresentado acima, a estrutura do Sinatra conta com suporte
embutido para uso de padrões de String e expressões regulares como
validadores de rota. No entanto, ele não pára por aí. Você pode
facilmente definir os seus próprios validadores:

``` ruby
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

Note que o exemplo acima pode ser robusto e complicado em excesso. Pode
também ser implementado como:

``` ruby
get // do
  pass if request.path_info == "/index"
  # ...
end
```

Ou, usando algo mais denso à frente:

``` ruby
get %r{^(?!/index$)} do
  # ...
end
```

## Arquivos estáticos

Arquivos estáticos são disponibilizados a partir do diretório
`./public`. Você pode especificar um local diferente pela opção
`:public_folder`

``` ruby
set :public_folder, File.dirname(__FILE__) + '/estatico'
```

Note que o nome do diretório público não é incluido na URL. Um arquivo
`./public/css/style.css` é disponibilizado como
`http://example.com/css/style.css`.

## Views / Templates

Templates presumem-se estar localizados sob o diretório `./views`. Para
utilizar um diretório view diferente:

``` ruby
set :views, File.dirname(__FILE__) + '/modelo'
```

Uma coisa importante a ser lembrada é que você sempre tem as referências
dos templates como símbolos, mesmo se eles estiverem em um sub-diretório
(nesse caso utilize `:'subdir/template'`). Métodos de renderização irão
processar qualquer string passada diretamente para elas.

### Haml Templates

A gem/biblioteca haml é necessária para renderizar templates HAML:

``` ruby
# Você precisa do 'require haml' em sua aplicação.
require 'haml'

get '/' do
  haml :index
end
```

Renderiza `./views/index.haml`.

[Opções
Haml](http://haml.info/docs/yardoc/file.HAML_REFERENCE.html#options)
podem ser setadas globalmente através das configurações do sinatra, veja
[Opções e Configurações](http://www.sinatrarb.com/configuration.html), e
substitua em uma requisição individual.

``` ruby
set :haml, {:format => :html5 } # o formato padrão do Haml é :xhtml

get '/' do
  haml :index, :haml_options => {:format => :html4 } # substituido
end
```

### Erb Templates

``` ruby
# Você precisa do 'require erb' em sua aplicação
require 'erb'

get '/' do
  erb :index
end
```

Renderiza `./views/index.erb`

### Erubis

A gem/biblioteca erubis é necessária para renderizar templates erubis:

``` ruby
# Você precisa do 'require erubis' em sua aplicação.
require 'erubis'

get '/' do
  erubis :index
end
```

Renderiza `./views/index.erubis`

### Builder Templates

A gem/biblioteca builder é necessária para renderizar templates builder:

``` ruby
# Você precisa do 'require builder' em sua aplicação.
require 'builder'

get '/' do
  content_type 'application/xml', :charset => 'utf-8'
  builder :index
end
```

Renderiza `./views/index.builder`.

### Sass Templates

A gem/biblioteca sass é necessária para renderizar templates sass:

``` ruby
# Você precisa do 'require haml' ou 'require sass' em sua aplicação.
require 'sass'

get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet
end
```

Renderiza `./views/stylesheet.sass`.

[Opções
Sass](http://sass-lang.com/docs/yardoc/file.SASS_REFERENCE.html#options)
podem ser setadas globalmente através das configurações do sinatra, veja
[Opções e Configurações](http://www.sinatrarb.com/configuration.html), e
substitua em uma requisição individual.

``` ruby
set :sass, {:style => :compact } # o estilo padrão do Sass é :nested

get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet, :style => :expanded # substituido
end
```

### Less Templates

A gem/biblioteca less é necessária para renderizar templates Less:

``` ruby
# Você precisa do 'require less' em sua aplicação.
require 'less'

get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  less :stylesheet
end
```

Renderiza `./views/stylesheet.less`.

### Inline Templates

``` ruby
get '/' do
  haml '%div.title Olá Mundo'
end
```

Renderiza a string, em uma linha, no template.

### Acessando Variáveis nos Templates

Templates são avaliados dentro do mesmo contexto como manipuladores de
rota. Variáveis de instância setadas em rotas manipuladas são
diretamente acessadas por templates:

``` ruby
get '/:id' do
  @foo = Foo.find(params[:id])
  haml '%h1= @foo.nome'
end
```

Ou, especifique um hash explícito para variáveis locais:

``` ruby
get '/:id' do
  foo = Foo.find(params[:id])
  haml '%h1= foo.nome', :locals => { :foo => foo }
end
```

Isso é tipicamente utilizando quando renderizamos templates como
partials dentro de outros templates.

### Templates Inline

Templates podem ser definidos no final do arquivo fonte(.rb):

``` ruby
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
%div.title Olá Mundo!!!!!
```

NOTA: Templates inline definidos no arquivo fonte são automaticamente
carregados pelo sinatra. Digite \`enable :inline\_templates\` se você
tem templates inline no outro arquivo fonte.

### Templates nomeados

Templates também podem ser definidos utilizando o método top-level
`template`:

``` ruby
template :layout do
  "%html\n  =yield\n"
end

template :index do
  '%div.title Olá Mundo!'
end

get '/' do
  haml :index
end
```

Se existir um template com nome “layout”, ele será utilizado toda vez
que um template for renderizado. Você pode desabilitar layouts passando
`:layout => false`.

``` ruby
get '/' do
  haml :index, :layout => !request.xhr?
end
```

## Helpers

Use o método de alto nível `helpers` para definir métodos auxiliares
para utilizar em manipuladores de rotas e modelos:

``` ruby
helpers do
  def bar(nome)
    "#{nome}bar"
  end
end

get '/:nome' do
  bar(params[:nome])
end
```

## Filtros

Filtros Before são avaliados antes de cada requisição dentro do contexto
da requisição e pode modificar a requisição e a reposta. Variáveis de
instância setadas nos filtros são acessadas através de rotas e
templates:

``` ruby
before do
  @nota = 'Oi!'
  request.path_info = '/foo/bar/baz'
end

get '/foo/*' do
  @nota #=> 'Oi!'
  params[:splat] #=> 'bar/baz'
end
```

Filtros After são avaliados após cada requisição dentro do contexto da
requisição e também podem modificar o pedido e a resposta. Variáveis de
instância definidas nos filtros before e rotas são acessadas através dos
filtros after:

``` ruby
after do
  puts response.status
end
```

Filtros opcionalmente tem um padrão, fazendo com que sejam avaliados
somente se o caminho do pedido coincidir com esse padrão:

``` ruby
before '/protected/*' do
  authenticate!
end

after '/create/:slug' do |slug|
  session[:last_slug] = slug
end
```

## Halting

Para parar imediatamente uma requisição com um filtro ou rota utilize:

``` ruby
halt
```

Você também pode especificar o status quando parar…

``` ruby
halt 410
```

Ou com corpo de texto…

``` ruby
halt 'isso será o corpo do texto'
```

Ou também…

``` ruby
halt 401, 'vamos embora!'
```

Com cabeçalhos…

``` ruby
halt 402, {'Content-Type' => 'text/plain'}, 'revanche'
```

## Passing

Uma rota pode processar aposta para a próxima rota correspondente usando
`pass`:

``` ruby
get '/adivinhar/:quem' do
  pass unless params[:quem] == 'Frank'
  'Você me pegou!'
end

get '/adivinhar/*' do
  'Você falhou!'
end
```

O bloqueio da rota é imediatamente encerrado e o controle continua com a
próxima rota de parâmetro. Se o parâmetro da rota não for encontrado, um
404 é retornado.

## Configuração

Rodando uma vez, na inicialização, em qualquer ambiente:

``` ruby
configure do
  ...
end
```

Rodando somente quando o ambiente (`RACK_ENV` environment variável) é
setado para `:production`:

``` ruby
configure :production do
  ...
end
```

Rodando quando o ambiente é setado para `:production` ou `:test`:

``` ruby
configure :production, :test do
  ...
end
```

## Tratamento de Erros

Tratamento de erros rodam dentro do mesmo contexto como rotas e filtros
before, o que significa que você pega todos os presentes que tem para
oferecer, como `haml`, `erb`, `halt`, etc.

### Não Encontrado

Quando um `Sinatra::NotFound` exception é levantado, ou o código de
status da reposta é 404, o `not_found` manipulador é invocado:

``` ruby
not_found do
  'Isto está longe de ser encontrado'
end
```

### Erro

O manipulador `error` é invocado toda a vez que uma exceção é lançada a
partir de um bloco de rota ou um filtro. O objeto da exceção pode ser
obtido a partir da variável Rack `sinatra.error`:

``` ruby
error do
  'Desculpe, houve um erro desagradável - ' + env['sinatra.error'].name
end
```

Erros customizados:

``` ruby
error MeuErroCustomizado do
  'Então que aconteceu foi...' + env['sinatra.error'].message
end
```

Então, se isso acontecer:

``` ruby
get '/' do
  raise MeuErroCustomizado, 'alguma coisa ruim'
end
```

Você receberá isso:

    Então que aconteceu foi... alguma coisa ruim

Alternativamente, você pode instalar manipulador de erro para um código
de status:

``` ruby
error 403 do
  'Accesso negado'
end

get '/secreto' do
  403
end
```

Ou um range:

``` ruby
error 400..510 do
  'Boom'
end
```

O Sinatra instala os manipuladores especiais `not_found` e `error`
quando roda sobre o ambiente de desenvolvimento.

## Mime Types

Quando utilizamos `send_file` ou arquivos estáticos você pode ter mime
types Sinatra não entendidos. Use `mime_type` para registrar eles por
extensão de arquivos:

``` ruby
mime_type :foo, 'text/foo'
```

Você também pode utilizar isto com o helper `content_type`:

``` ruby
content_type :foo
```

## Middleware Rack

O Sinatra roda no [Rack](http://rack.rubyforge.org/), uma interface
padrão mínima para frameworks web em Ruby. Um das capacidades mais
interessantes do Rack para desenvolver aplicativos é suporte a
“middleware” – componentes que ficam entre o servidor e sua aplicação
monitorando e/ou manipulando o request/response do HTTP para prover
vários tipos de funcionalidades comuns.

O Sinatra faz construtores pipelines do middleware Rack facilmente em um
nível superior utilizando o método `use`:

``` ruby
require 'sinatra'
require 'meu_middleware_customizado'

use Rack::Lint
use MeuMiddlewareCustomizado

get '/ola' do
  'Olá mundo'
end
```

A semântica de `use` é idêntica aquela definida para a DSL
[Rack::Builder](http://rack.rubyforge.org/doc/classes/Rack/Builder.html)
(mais frequentemente utilizada para arquivos rackup). Por exemplo, o
método `use` aceita múltiplos argumentos/variáveis bem como blocos:

``` ruby
use Rack::Auth::Basic do |usuario, senha|
  usuario == 'admin' && senha == 'secreto'
end
```

O Rack é distribuido com uma variedade de middleware padrões para logs,
debugs, rotas de URL, autenticação, e manipuladores de sessão. Sinatra
utilizada muitos desses componentes automaticamente baseando sobre
configuração, então, tipicamente você não tem `use` explicitamente.

## Testando

Testes no Sinatra podem ser escritos utilizando qualquer biblioteca ou
framework de teste baseados no Rack.
[Rack::Test](http://gitrdoc.com/brynary/rack-test) é recomendado:

``` ruby
require 'minha_aplicacao_sinatra'
require 'rack/test'

class MinhaAplicacaoTeste < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def meu_test_default
    get '/'
    assert_equal 'Ola Mundo!', last_response.body
  end

  def teste_com_parametros
    get '/atender', :name => 'Frank'
    assert_equal 'Olá Frank!', last_response.bodymeet
  end

  def test_com_ambiente_rack
    get '/', {}, 'HTTP_USER_AGENT' => 'Songbird'
    assert_equal "Você está utilizando o Songbird!", last_response.body
  end
end
```

NOTA: Os módulos de classe embutidos `Sinatra::Test` e
`Sinatra::TestHarness` são depreciados na versão 0.9.2.

## Sinatra::Base - Middleware, Bibliotecas e aplicativos modulares

Definir sua aplicação em um nível superior de trabalho funciona bem para
micro aplicativos, mas tem consideráveis incovenientes na construção de
componentes reutilizáveis como um middleware Rack, metal Rails,
bibliotecas simples como um componente de servidor, ou mesmo extensões
Sinatra. A DSL de nível superior polui o espaço do objeto e assume um
estilo de configuração de micro aplicativos (exemplo: uma simples
arquivo de aplicação, diretórios `./public` e `./views`, logs, página de
detalhes de exceção, etc.). É onde o `Sinatra::Base` entra em jogo:

``` ruby
require 'sinatra/base'

class MinhaApp < Sinatra::Base
  set :sessions, true
  set :foo, 'bar'

  get '/' do
    'Ola mundo!'
  end
end
```

A classe `MinhaApp` é um componente Rack independente que pode agir como
um middleware Rack, uma aplicação Rack, ou metal Rails. Você pode
utilizar ou executar esta classe com um arquivo rackup `config.ru`;
ou, controlar um componente de servidor fornecendo como biblioteca:

``` ruby
MinhaApp.run! :host => 'localhost', :port => 9090
```

Os métodos disponíveis para subclasses `Sinatra::Base` são exatamente como
aqueles disponíveis via a DSL de nível superior. Aplicações de nível
mais alto podem ser convertidas para componentes `Sinatra::Base` com duas
modificações:

-   Seu arquivo deve requerer `sinatra/base` ao invés de `sinatra`;
    outra coisa, todos os métodos DSL do Sinatra são importados para o
    espaço principal.

-   Coloque as rotas da sua aplicação, manipuladores de erro, filtros e
    opções na subclasse de um `Sinatra::Base`.

`Sinatra::Base` é um quadro branco. Muitas opções são desabilitadas por
padrão, incluindo o servidor embutido. Veja [Opções e
Configurações](http://sinatra.github.com/configuration.html) para
detalhes de opções disponíveis e seus comportamentos.

SIDEBAR: A DSL de alto nível do Sinatra é implementada utilizando um simples
sistema de delegação. A classe `Sinatra::Application` – uma subclasse especial
da `Sinatra::Base` – recebe todos os `:get`, `:put`, `:post`, `:delete`,
`:before`, `:error`, `:not_found`, `:configure`, e `:set messages` enviados
para o alto nível. Dê uma olhada no código você mesmo: aqui está o
[Sinatra::Delegator
mixin](http://github.com/sinatra/sinatra/blob/ceac46f0bc129a6e994a06100aa854f606fe5992/lib/sinatra/base.rb#L1128)
sendo [incluido dentro de um espaço
principal](http://github.com/sinatra/sinatra/blob/ceac46f0bc129a6e994a06100aa854f606fe5992/lib/sinatra/main.rb#L28)

## Linha de Comando

Aplicações Sinatra podem ser executadas diretamente:

``` shell
ruby minhaapp.rb [-h] [-x] [-e AMBIENTE] [-p PORTA] [-o HOST] [-s SERVIDOR]
```

As opções são:

```
-h # ajuda
-p # define a porta (padrão é 4567)
-o # define o host (padrão é 0.0.0.0)
-e # define o ambiente (padrão é development)
-s # especifica o servidor/manipulador rack (padrão é thin)
-x # ativa o bloqueio (padrão é desligado)
```

## A última versão

Se você gostaria de utilizar o código da última versão do Sinatra, crie
um clone local e execute sua aplicação com o diretório `sinatra/lib` no
`LOAD_PATH`:

``` shell
cd minhaapp
git clone git://github.com/sinatra/sinatra.git
ruby -I sinatra/lib minhaapp.rb
```

Alternativamente, você pode adicionar o diretório do `sinatra/lib` no
`LOAD_PATH` do seu aplicativo:

``` ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/sinatra/lib'
require 'rubygems'
require 'sinatra'

get '/sobre' do
  "Estou rodando a versão" + Sinatra::VERSION
end
```

Para atualizar o código do Sinatra no futuro:

``` shell
cd meuprojeto/sinatra
git pull
```

## Mais

-   [Website do Projeto](http://www.sinatrarb.com/) - Documentação
    adicional, novidades e links para outros recursos.

-   [Contribuir](http://www.sinatrarb.com/contributing) - Encontrar um
    bug? Precisa de ajuda? Tem um patch?

-   [Acompanhar Questões](http://github.com/sinatra/sinatra/issues)

-   [Twitter](http://twitter.com/sinatra)

-   [Lista de Email](http://groups.google.com/group/sinatrarb/topics)

-   [IRC: \#sinatra](irc://chat.freenode.net/#sinatra) em
    [freenode.net](http://freenode.net)
