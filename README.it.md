# Sinatra

Sinatra é un [DSL](http://it.wikipedia.org/wiki/Domain-specific_language) per creare rapidamente delle web applications in Ruby con il minimo sforzo:

``` ruby
# myapp.rb
require 'sinatra'

get '/' do
  'Hello world!'
end
```

Installa la gemma:

``` shell
gem install sinatra
```

Esegui il programma con:

``` shell
ruby myapp.rb
```

Guarda il risultato su: http://localhost:4567

Si raccomanda di eseguire `gem install thin`, Sinatra utilizzera thin quando disponibile.

## Indice

* [Sinatra](#sinatra)
    * [Indice](#indice)
    * [Routes](#routes)
    * [Condizioni](#condizioni)
    * [Valori ritornati](#valori-ritornati)
    * [Routes personalizzate](#routes-con-pattern-personalizzati)
    * [Files statici](#files-statici)
    * [Views / Templates](#views--templates)
        * [Literal Templates](#literal-templates)
        * [Linguaggi disponibili per i templates](#linguaggi-disponibili-per-i-templates)
            * [Haml Templates](#haml-templates)
            * [Erb Templates](#erb-templates)
            * [Builder Templates](#builder-templates)
            * [Nokogiri Templates](#nokogiri-templates)
            * [Sass Templates](#sass-templates)
            * [SCSS Templates](#scss-templates)
            * [Less Templates](#less-templates)
            * [Liquid Templates](#liquid-templates)
            * [Markdown Templates](#markdown-templates)
            * [Textile Templates](#textile-templates)
            * [RDoc Templates](#rdoc-templates)
            * [Radius Templates](#radius-templates)
            * [Markaby Templates](#markaby-templates)
            * [RABL Templates](#rabl-templates)
            * [Slim Templates](#slim-templates)
            * [Creole Templates](#creole-templates)
            * [CoffeeScript Templates](#coffeescript-templates)
            * [Stylus Templates](#stylus-templates)
            * [Yajl Templates](#yajl-templates)
            * [WLang Templates](#wlang-templates)
        * [Accedere alle variabili nel template](#accedere-alle-variabili-nel-template)
        * [Templates con `yield` e layouts annidati](#templates-con-yield-e-layouts-annidati)
        * [Inline Templates](#inline-templates)
        * [Named Templates](#named-templates)
        * [Associare le estensioni dei files](#associare-le-estensioni-dei-files)
        * [Aggiungi il tuo Template Engine personale](#aggiungi-il-tuo-template-engine-personale)
    * [Filtri](#filteri)
    * [Helpers](#helpers)
        * [Usare le sessioni](#usare-le-sessioni)
        * [Halting](#halting)
        * [Passing](#passing)
        * [Innescare una altra route](#innescare-un-altra-route)
        * [Definire il Body, lo Status Code e gli Headers](#defnire-il-body-lo-status-code-e-gli-headers)
        * [Streaming Responses](#streaming-responses)
        * [Logging](#logging)
        * [Mime Types](#mime-types)
        * [Generare URLs](#generare-urls)
        * [Browser Redirect](#browser-redirect)
        * [Gestire la Cache](#gestire-la-cache)
        * [Inviare Files](#inviare-files)
        * [Accedere all'oggetto Request](#accedre-alloggetto-request)
        * [Allegati](#allegati)
        * [Utilizzare Date and Time](#utilizzare-date-and-time)
        * [Ricercare i Template Files](#ricercare-i-template-files)
    * [Configurazione](#configurazione)
        * [Configurare la protezione per gli attacchi](#configurare-la-protezione-per-gli-attacchi)
        * [Configurazioni disponibili](#configurazioni-disponibili)
    * [Ambienti](#ambienti)
    * [Gestione degli errori](#gestione-degli-errori)
        * [Non trovato](#non-trovato)
        * [Errore](#errore)
    * [Rack Middleware](#rack-middleware)
    * [Testare](#testare)
    * [Sinatra::Base - Middleware, Librerie, e Applicazioni Modulari](#sinatrabase---middleware-librerie-and-applicazioni-modulari)
        * [Modulare vs. Classic Style](#modular-vs-classic-style)
        * [Esporre un applicazione modulare](#esporre-un-applicazione-modulare)
        * [Usare una Classic Style Application con config.ru](#usare-una-classic-style-application-con-configru)
        * [Quando utilizzare config.ru?](#quando-utilizzare-configru)
        * [Utilizzare Sinatra come Middleware](#utilizzare-sinatra-come-middleware)
        * [Creazione dinamica di applicazioni](#creazione-dinamica-di-applicazioni)
    * [Scopes e Binding](#scopes-e-binding)
        * [Application/Class Scope](#applicationclass-scope)
        * [Request/Instance Scope](#requestinstance-scope)
        * [Delegation Scope](#delegation-scope)
    * [Linea di comando](#linea-di-comando)
    * [Requisiti](#requisiti)
    * [The Bleeding Edge](#the-bleeding-edge)
        * [Con Bundler](#con-bundler)
        * [Fai da te](#fai-da-te)
        * [Installazione Globale](#installazione-globale)
    * [Versioning](#versioning)
    * [Voci correlate](#voci-correlate)

## Routes

In Sinatra, una route é un metodo HTTP collegato con un pattern URL che permette l'nstradamento delle richieste.
Ogni route é associata a un blocco:

``` ruby
get '/' do
  .. show something ..
end

post '/' do
  .. create something ..
end

put '/' do
  .. replace something ..
end

patch '/' do
  .. modify something ..
end

delete '/' do
  .. annihilate something ..
end

options '/' do
  .. appease something ..
end

link '/' do
  .. affiliate something ..
end

unlink '/' do
  .. separate something ..
end
```

Le Routes sono elaborate in cascata nell'ordine in cui soo definite. La prima Route a combaciare con la richiesta sarà quella invicata.

I pattern delle route possono includere dei parametri nominali, accessibili tramite:
`params` hash:

``` ruby
get '/hello/:name' do
  # matches "GET /hello/foo" and "GET /hello/bar"
  # params[:name] is 'foo' or 'bar'
  "Hello #{params[:name]}!"
end
```

Si può inoltre accedere ai parametri nominali tramite i parametri di un blocco:

``` ruby
get '/hello/:name' do |n|
  # matches "GET /hello/foo" and "GET /hello/bar"
  # params[:name] is 'foo' or 'bar'
  # n stores params[:name]
  "Hello #{n}!"
end
```

I pattern delle routes possono anche includere dei parametri splat (o wildcard), accessibili
tramite l'array `params[:splat]`:

``` ruby
get '/say/*/to/*' do
  # matches /say/hello/to/world
  params[:splat] # => ["hello", "world"]
end

get '/download/*.*' do
  # matches /download/path/to/file.xml
  params[:splat] # => ["path/to/file", "xml"]
end
```

O con dei parametri di blocco:

``` ruby
get '/download/*.*' do |path, ext|
  [path, ext] # => ["path/to/file", "xml"]
end
```

Le routes possono anche essere definite con una regular expression:

``` ruby
get %r{/hello/([\w]+)} do
  "Hello, #{params[:captures].first}!"
end
```

O con il parametro di un blocco:

``` ruby
get %r{/hello/([\w]+)} do |c|
  "Hello, #{c}!"
end
```

Le Routes possono anche prevedere dei parametri opzionali:

``` ruby
get '/posts.?:format?' do
  # matches "GET /posts" and any extension "GET /posts.json", "GET /posts.xml" etc.
end
```

Comunque, a meno di disabilitare la Trasversal Attack protection (vedi sotto),
l'URL della richiesta potrebbe essere stato modificato prima di essere stato comparato a una delle tue routes.


## Condizioni

Le Routes possono includere una gran varietà di condizioni, tra le quali gli 'user agent':


``` ruby
get '/foo', :agent => /Songbird (\d\.\d)[\d\/]*?/ do
  "You're using Songbird version #{params[:agent][0]}"
end

get '/foo' do
  # Matches non-songbird browsers
end
```

Altre condizioni disponibili sono `host_name` e `provides`:

``` ruby
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

Puoi facilmente definire le tue condizioni:

``` ruby
set(:probability) { |value| condition { rand <= value } }

get '/win_a_car', :probability => 0.1 do
  "You won!"
end

get '/win_a_car' do
  "Sorry, you lost."
end
```

Per una condizione che utilizza valori multipli utilizza l'operatore splat(*):

``` ruby
set(:auth) do |*roles|   # <- notice the splat here
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

## Valori ritornati

I valori ritornati da un blocco route determinano il response body passato al client HTTP, o al prossimo middleware dello stack Rack.
Spesso é una stringa, come nel ultimo esempio del capitolo Routes, ma sono accettati anche altri valori.

Puoi restituire qualsiasi oggetto che potrebbe essere una risposta valida Rack, un oggetto Rack body o lo status code HTTP:

* Un Array con tré elementi: `[status (Fixnum), headers (Hash), response
  body (responds to #each)]`
* Un Array con due elementi: `[status (Fixnum), response body (responds to
  #each)]`
* Un oggetto che risponde a `#each` e che passa delle stringhe al blocco.
* Un Fixnum che rappresenta lo status code HTTP.

Per esempio per implementare un semplice stream:

``` ruby
class Stream
  def each
    100.times { |i| yield "#{i}\n" }
  end
end

get('/') { Stream.new }
```

Puoi anche usare l'helper `stream` (descritto sotto)
You can also use the `stream` helper method (described below) per essere più chiari e includere la logica di streaming nella route.

## Routes con pattern personalizzati

Come mostrato sopra, Sinatra fornisce un supporto integrto per utilizzare dei pattern di stringe e le regular expression per instradare le chiamate. Tuttavia non si ferma qui. Puoi facilmente definire dei pattern personalizzati:

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

L'esempio qui sopra può essere visto come un over-engineer, dato che si può anche definire come:

``` ruby
get // do
  pass if request.path_info == "/index"
  # ...
end
```

O, utilizzando una forma negativa:

``` ruby
get %r{^(?!/index$)} do
  # ...
end
```

## Files statici

I files statici vengono esposti tramite la directory `./public`. Puoi specificare una posizione differente impostando l'opzione `:public_folder`.

``` ruby
set :public_folder, File.dirname(__FILE__) + '/static'
```

Nota che il nome della directory public non é presente nel'URL. Il file `./public/css/style.css` per esempio sarebbe reso disponibile come: `http://example.com/css/style.css`.

Usa l'opzione `:static_cache_control` (vedi stto) per aggiungere `Cache-Control` alle informazioni dell'header.

## Views / Templates

Ogni linguaggio di template é esposto tramite il suo metodo di rendering, il quale ritorna semplicemente una stringa:

``` ruby
get '/' do
  erb :index
end
```

Renderizza: `views/index.erb`.

Invece del nome del template, puoi anche passare direttamente nel contenuto del template:


``` ruby
get '/' do
  code = "<%= Time.now %>"
  erb code
end
```
I metodi per i template accettano un secondo parametro, la hash options:

``` ruby
get '/' do
  erb :index, :layout => :post
end
```

Questo renderizza `views/index.erb` integrato in
`views/post.erb` (il valore di default é `views/layout.erb`, se questo esiste).

Ogni ppzione non contemplata da Sinatra sarà passata direttamente al template:

``` ruby
get '/' do
  haml :index, :format => :html5
end
```

Puoi anche impostare le opzioni relativa al linguaggio di ogni template:

``` ruby
set :haml, :format => :html5

get '/' do
  haml :index
end
```

Le opzioni passate al metodo render sovrascrivono quelle passate tramite il metodo `set`.

Opzioni disponibili:

<dl>
  <dt>locals</dt>
  <dd>
    Lista di variabili locali passate al documento. Molto utili con i partials.
    Esempio: <tt>erb "<%= foo %>", :locals => {:foo => "bar"}</tt>
  </dd>

  <dt>default_encoding</dt>
  <dd>
    Encoding delle stringhe da utilizzare in caso di indecisione. Di default
    <tt>settings.default_encoding</tt>.
  </dd>

  <dt>views</dt>
  <dd>
    Directory da cui caricare le Views. Di default <tt>settings.views</tt>.
  </dd>

  <dt>layout</dt>
  <dd>
    Se utilizzare o meno un layout (<tt>true</tt> o <tt>false</tt>). Se é un Symbol, specifica quale template utilizzare. Esempio: <tt>erb :index, :layout => !request.xhr?</tt>
  </dd>

  <dt>content_type</dt>
  <dd>
    Il Content-Type prodotto dal template. Di default dipende dal linguaggio del template.
  </dd>

  <dt>scope</dt>
  <dd>
    Lo Scope(contesto) con il quale renderizzare il template. Di defaults utilizza l'istanza dell'applicazione. Se cambiato, le variabili di istanza e gli helper methods non saranno disponibili.
  </dd>

  <dt>layout_engine</dt>
  <dd>
    Template engine utilizzato per renderizzare il layout. Utile per i linguaggi che altrimenti non supportano i layout. Di default l'engine utilizzato per il template. Esempio: <tt>set :rdoc, :layout_engine => :erb</tt>
  </dd>

  <dt>layout_options</dt>
  <dd>
    Opzioni speciali utilizzate unicamente per renderizzare il layout. Esempio:
    <tt>set :rdoc, :layout_options => { :views => 'views/layouts' }</tt>
  </dd>
</dl>

Si suppone che i templates siajno locati nella directory `./views`.
Per utilizzare un altra directory:

``` ruby
set :views, settings.root + '/templates'
```

È importante ricordare di referenziare sempre i templates con dei symbols, anche se questi sono in una subdirectory (per esempio: `:'subdir/template'` o `'subdir/template'.to_sym`). Bisogna utilizzare un symbol dato che i metodi di rendering a cui viene passata una stringa, renderizzano la stessa invece del layout.


### Literal Templates

``` ruby
get '/' do
  haml '%div.title Hello World'
end
```

Renderizza il codice del template descritto nella stringa.

### Linguaggi disponibili per i templates

Alcuni linguaggi hanno implementazioni multiple. Per specificare quale implementazione utilizzare (e per essere thread-safe), bisogna semplicemente fare il require:

``` ruby
require 'rdiscount' # or require 'bluecloth'
get('/') { markdown :index }
```

#### Haml Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://haml.info/" title="haml">haml</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.haml</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>haml :index, :format => :html5</tt></td>
  </tr>
</table>

#### Erb Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td>
      <a href="http://www.kuwata-lab.com/erubis/" title="erubis">erubis</a>
      or erb (included in Ruby)
    </td>
  </tr>
  <tr>
    <td>File Extensions</td>
    <td><tt>.erb</tt>, <tt>.rhtml</tt> or <tt>.erubis</tt> (Erubis only)</td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>erb :index</tt></td>
  </tr>
</table>

#### Builder Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td>
      <a href="http://builder.rubyforge.org/" title="builder">builder</a>
    </td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.builder</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>builder { |xml| xml.em "hi" }</tt></td>
  </tr>
</table>

Accetta anche blocchi come inline template (vedi esempio).

#### Nokogiri Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://nokogiri.org/" title="nokogiri">nokogiri</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.nokogiri</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>nokogiri { |xml| xml.em "hi" }</tt></td>
  </tr>
</table>

Accetta anche blocchi come inline template (vedi esempio).

#### Sass Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://sass-lang.com/" title="sass">sass</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.sass</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>sass :stylesheet, :style => :expanded</tt></td>
  </tr>
</table>

#### SCSS Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://sass-lang.com/" title="sass">sass</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.scss</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>scss :stylesheet, :style => :expanded</tt></td>
  </tr>
</table>

#### Less Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://www.lesscss.org/" title="less">less</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.less</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>less :stylesheet</tt></td>
  </tr>
</table>

#### Liquid Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://www.liquidmarkup.org/" title="liquid">liquid</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.liquid</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>liquid :index, :locals => { :key => 'value' }</tt></td>
  </tr>
</table>

Siccome non si può chiamare metodi Ruby (tranne `yield`) da un Liquid Template, si utilizza quasi sempre una variabile `locale`.

#### Markdown Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td>
      Anyone of:
        <a href="https://github.com/rtomayko/rdiscount" title="RDiscount">RDiscount</a>,
        <a href="https://github.com/vmg/redcarpet" title="RedCarpet">RedCarpet</a>,
        <a href="http://deveiate.org/projects/BlueCloth" title="BlueCloth">BlueCloth</a>,
        <a href="http://kramdown.rubyforge.org/" title="kramdown">kramdown</a>,
        <a href="http://maruku.rubyforge.org/" title="maruku">maruku</a>
    </td>
  </tr>
  <tr>
    <td>File Extensions</td>
    <td><tt>.markdown</tt>, <tt>.mkd</tt> and <tt>.md</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>markdown :index, :layout_engine => :erb</tt></td>
  </tr>
</table>

Non é possibile chiamare metodi da markdown ne passare viaribili `locale`.
Questo porta normalemente ad utilizzare markdown inseme ad un altro motore di rendering:


``` ruby
erb :overview, :locals => { :text => markdown(:introduction) }
```

Nota che si puù sempre chiamare il metodo `markdown` dall'interno di un altro template:

``` ruby
%h1 Hello From Haml!
%p= markdown(:greetings)
```

Dato che non puoi chiamare Ruby da Markdown, non puoi usare dei layout scritti in Markdown.
Invece si può utilizzare un altro motore di rendering appositamente per il layout passando l'opzione `:layout_engine`.

#### Textile Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://redcloth.org/" title="RedCloth">RedCloth</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.textile</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>textile :index, :layout_engine => :erb</tt></td>
  </tr>
</table>

Non é possibile chiamare metodi da markdown ne passare viaribili `locale`.
Questo porta normalemente ad utilizzare textile inseme ad un altro motore di rendering:

``` ruby
erb :overview, :locals => { :text => textile(:introduction) }
```

Nota che si puù sempre chiamare il metodo `textile` dall'interno di un altro template:

``` ruby
%h1 Hello From Haml!
%p= textile(:greetings)
```

Dato che non puoi chiamare Ruby da Textile, non puoi usare dei layout scritti in Textile.
Invece si può utilizzare un altro motore di rendering appositamente per il layout passando l'opzione `:layout_engine`.

#### RDoc Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://rdoc.rubyforge.org/" title="RDoc">RDoc</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.rdoc</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>rdoc :README, :layout_engine => :erb</tt></td>
  </tr>
</table>

Non é possibile chiamare metodi da rdoc ne passare viaribili `locale`.
Questo porta normalemente ad utilizzare rdoc inseme ad un altro motore di rendering:

``` ruby
erb :overview, :locals => { :text => rdoc(:introduction) }
```

Nota che si puù sempre chiamare il metodo `rdoc` dall'interno di un altro template:

``` ruby
%h1 Hello From Haml!
%p= rdoc(:greetings)
```

Dato che non puoi chiamare Ruby da rdoc, non puoi usare dei layout scritti in rdoc.
Invece si può utilizzare un altro motore di rendering appositamente per il layout passando l'opzione `:layout_engine`.

#### Radius Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://radius.rubyforge.org/" title="Radius">Radius</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.radius</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>radius :index, :locals => { :key => 'value' }</tt></td>
  </tr>
</table>

Siccome non si può chiamare metodi Ruby da un template Radius, si utilizza quasi sempre una variabile `locale`.

#### Markaby Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://markaby.github.com/" title="Markaby">Markaby</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.mab</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>markaby { h1 "Welcome!" }</tt></td>
  </tr>
</table>

Accetta anche blocchi come inline template (vedi esempio).

#### RABL Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="https://github.com/nesquena/rabl" title="Rabl">Rabl</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.rabl</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>rabl :index</tt></td>
  </tr>
</table>

#### Slim Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="http://slim-lang.com/" title="Slim Lang">Slim Lang</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.slim</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>slim :index</tt></td>
  </tr>
</table>

#### Creole Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="https://github.com/minad/creole" title="Creole">Creole</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.creole</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>creole :wiki, :layout_engine => :erb</tt></td>
  </tr>
</table>

Non é possibile chiamare metodi da creole ne passare viaribili `locale`.
Questo porta normalemente ad utilizzare creole inseme ad un altro motore di rendering:

``` ruby
erb :overview, :locals => { :text => creole(:introduction) }
```

Nota che si puù sempre chiamare il metodo `creole` dall'interno di un altro template:

``` ruby
%h1 Hello From Haml!
%p= creole(:greetings)
```

Dato che non puoi chiamare Ruby da Creole, non puoi usare dei layout scritti in Creole.
Invece si può utilizzare un altro motore di rendering appositamente per il layout passando l'opzione `:layout_engine`.

#### CoffeeScript Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td>
      <a href="https://github.com/josh/ruby-coffee-script" title="Ruby CoffeeScript">
        CoffeeScript
      </a> and a
      <a href="https://github.com/sstephenson/execjs/blob/master/README.md#readme" title="ExecJS">
        way to execute javascript
      </a>
    </td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.coffee</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>coffee :index</tt></td>
  </tr>
</table>

#### Stylus Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td>
      <a href="https://github.com/lucasmazza/ruby-stylus" title="Ruby Stylus">
        Stylus
      </a> and a
      <a href="https://github.com/sstephenson/execjs/blob/master/README.md#readme" title="ExecJS">
        way to execute javascript
      </a>
    </td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.styl</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>stylus :index</tt></td>
  </tr>
</table>

Prima di poter utilizzare i templates Stylus, bisogna caricare `stylus` e `stylus/tilt`:

``` ruby
require 'sinatra'
require 'stylus'
require 'stylus/tilt'

get '/' do
  stylus :example
end
```

#### Yajl Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="https://github.com/brianmario/yajl-ruby" title="yajl-ruby">yajl-ruby</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.yajl</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
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


Il codice del template viene trattato come una stringa Ruby, e la variabile json che ne risulta viene convertita utilizzando `#to_json`:

``` ruby
json = { :foo => 'bar' }
json[:baz] = key
```

Le opzioni `:callback` e `:variable` sono utilizzate per "decorare" l'oggetto renderizzato:


``` ruby
var resource = {"foo":"bar","baz":"qux"}; present(resource);
```

#### WLang Templates

<table>
  <tr>
    <td>Dipendenza</td>
    <td><a href="https://github.com/blambeau/wlang/" title="wlang">wlang</a></td>
  </tr>
  <tr>
    <td>Estensione del file</td>
    <td><tt>.wlang</tt></td>
  </tr>
  <tr>
    <td>Esempio</td>
    <td><tt>wlang :index, :locals => { :key => 'value' }</tt></td>
  </tr>
</table>

Dal momento che chiamare metodi Ruby in Wlang non é idiomatico, normalemente si utilizza una variabile di tipo `locale`. Sono supportati i layouts scritti in Wlang e l'utilizzo di `yield`.

### Accedere alle variabili nel template

I template sono trattati all'interno del medesimo contesto che gestisce le routes. Le variabili di istanza impostate nella route, sono quindi accessibili direttamente dai template:

``` ruby
get '/:id' do
  @foo = Foo.find(params[:id])
  haml '%h1= @foo.name'
end
```

O specificando una hash di variabili locali:

``` ruby
get '/:id' do
  foo = Foo.find(params[:id])
  haml '%h1= bar.name', :locals => { :bar => foo }
end
```

Questa funzionalità é utilizzata tipicamente quando si rtenderizzano dei partials all'interno di altri templates.

### Templates con yield e layouts annidati

Un layout solitamente non é niente di più di un template che chiama `yield`.
Questo template può essere utilizzato, sia tramite l'opzione template come descritto sopra, o può essere renderizzato con un blocco come nell'esempio seguente:

``` ruby
erb :post, :layout => false do
  erb :index
end
```

Questo codice é equivalente a `erb :index, :layout => :post`.

Passare dei blocchi ai metodi di rendering é motlo utilie per creare dei layouts annidati:

``` ruby
erb :main_layout, :layout => false do
  erb :admin_layout do
    erb :user
  end
end
```

Questo può anche essere eseguito in meno linee con:

``` ruby
erb :admin_layout, :layout => :main_layout do
  erb :user
end
```

Attualmente sono i seguenti metodi di rendering che accettano un blocco come parametro: `erb`, `haml`,`liquid`, `slim `, `wlang`.
Anche il metodo generico `render` accetta un blocco.

### Inline Templates

I templates possono essere definiti alla fine del file contenente il codice sorgente:

``` ruby
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
NOTA: I template inline definiti all'interno del codice sorgente che utilizza(require) **sinatra** sono caricati automaticamente. Utilizza `enable :inline_templates` esplicitamente se hai dei template inline definiti in altri sorgenti.


### Named Templates

I template possono anche essere definiti utilizzando il metodo top-level `template` :

``` ruby
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

Se un template denominato "layout" esiste, questo verrà utilizzato ogni volta che viene renderizzato un template. Puoi disabilitare puntualmente il layout passandi `:layout => false` o disabilitandolo di default via `set :haml, :layout => false` :

``` ruby
get '/' do
  haml :index, :layout => !request.xhr?
end
```

### Associare le estensioni dei files

Per assiociare l'estensione dei file al template engine, usa `Tilt.register`, Per esempio, se vuoi utilizzare l'estensione `tt` per i templates Textile puoi fare come segue:

``` ruby
Tilt.register :tt, Tilt[:textile]
```

### Aggiungi il tuo Template Engine personale

Primo, registra il tuo engine con Tilt, poi crea un metodo di rendering:

``` ruby
Tilt.register :myat, MyAwesomeTemplateEngine

helpers do
  def myat(*args) render(:myat, *args) end
end

get '/' do
  myat :index
end
```

Renderizza `./views/index.myat`. Vedi https://github.com/rtomayko/tilt per saperne di più sull'argomento.

## Filtri

I metodi Before filters vengono eseguiti prima di ogni richiesta all'interno del contesto della route e può modificare la richiesta e la risposta. Le variabili d'istanza definite e impostate nei filtri sono accessibili dalle route e dai templates.

``` ruby
before do
  @note = 'Hi!'
  request.path_info = '/foo/bar/baz'
end

get '/foo/*' do
  @note #=> 'Hi!'
  params[:splat] #=> 'bar/baz'
end
```

I metodi After filters vengono eseguiti dopo di ogni richiesta all'interno del contesto della route e può modificare la richiesta e la risposta.
Le variabili d'istanza definite e impostate nei before filters e nelle routes sono accessibili dagli after filters.

``` ruby
after do
  puts response.status
end
```
Nota: A meno di utlizzare il metodo `body` invece di ritornare una stringa all'interno delle routes il body non sarà disponibile per il metodo after filter. Questo perché il body vien elaborato più avanti.

I filtri possono accettare un pattern, questo comporta che il filtro in questione venga elaborato solo ala corripondenza con il pattern impostato:

``` ruby
before '/protected/*' do
  authenticate!
end

after '/create/:slug' do |slug|
  session[:last_slug] = slug
end
```

Come le routes anche i filtri accettano delle condiozioni:

``` ruby
before :agent => /Songbird/ do
  # ...
end

after '/blog/*', :host_name => 'example.com' do
  # ...
end
```

## Helpers

Utilizza il metodo top-level `helpers` per definire dei nuovi helper methods da utilizzare nelle routes e nei templates:

``` ruby
helpers do
  def bar(name)
    "#{name}bar"
  end
end

get '/:name' do
  bar(params[:name])
end
```

Alternativamente gli helper si possono definire in un modulo:

``` ruby
module FooUtils
  def foo(name) "#{name}foo" end
end

module BarUtils
  def bar(name) "#{name}bar" end
end

helpers FooUtils, BarUtils
```

L'effetto é il medesimo che aggiungere i moduli alla classe principale dell'applicazione.

### Usare le sessioni

Una sessione viene utilizzata per mantenere lo stato durante richieste differenti. Se attivate, avrai una hash sessione per ogni sessione utente:

``` ruby
enable :sessions

get '/' do
  "value = " << session[:value].inspect
end

get '/:value' do
  session[:value] = params[:value]
end
```

Nota che `enable :sessions` salva i dati in un cookie. Questo
potrebbe non essere quello che vuoi (salvare molti dati aumenterà il traffico per istanza).
Puoi usare qualsiasi Rack middleware che tratta le sessioni in modo di poter fare così:
**non** chiamare `enable :sessions`, ma invece utilizzare un middleware di tua scelta:

``` ruby
use Rack::Session::Pool, :expire_after => 2592000

get '/' do
  "value = " << session[:value].inspect
end

get '/:value' do
  session[:value] = params[:value]
end
```
Per migliorare la sicurezza i  dati della sessione all'interno del cookie sono
signed (firmati/autnticati) con una hash segreta (secret).
Un secret random viene genrato per te da Sinatra. Comunque, dato che quetso secret
viene generato automaticamente ad ogni riavvio della tua applicazione potresti voler
impostare un secret manualmente in modo che tutte le istance della tua applicazione lo
utilizzino:

``` ruby
set :session_secret, 'super secret'
```

Se vuoi configurarlo ulteriormente, puoi anche una hash con le opzioni nei
`sessions` setting:

``` ruby
set :sessions, :domain => 'foo.com'
```
Per condividere la tua sessione con altre applicazioni sul dominio foo.com,
aggiungi il prefisso *.* in questo modo:

``` ruby
set :sessions, :domain => '.foo.com'
```

### Halting

Per fermare immediatamente una richiesta all'interno di un filtro o una route usa:

``` ruby
halt
```

Puoi anche specificare lo status quando chiami halt:

``` ruby
halt 410
```

O il body:

``` ruby
halt 'this will be the body'
```

Or entrambi:

``` ruby
halt 401, 'go away!'
```

Aggiungere degli headers:

``` ruby
halt 402, {'Content-Type' => 'text/plain'}, 'revenge'
```

È anche possibile combinare un template con `halt`:

``` ruby
halt erb(:error)
```

### Passing

Una route puo diroztare un processo alla prossima route corrispondente utilizzando `pass`:

``` ruby
get '/guess/:who' do
  pass unless params[:who] == 'Frank'
  'You got me!'
end

get '/guess/*' do
  'You missed!'
end
```
Il blocco della route viene abbandonato immediatamente e il processo continua con la prossima
route che combacia. Se non viene trovata nessuna route adatta viene ritornato un 404.


### Innescare una altra route

A volte `pass` non fa esattamente quello che vuoi, invece potresti voler ricevere
il risultato della chiamata di un altra route. Puoi utilizzare `call` per
raggiungere questo risultato:

``` ruby
get '/foo' do
  status, headers, body = call env.merge("PATH_INFO" => '/bar')
  [status, headers, body.map(&:upcase)]
end

get '/bar' do
  "bar"
end
```
Nota che nell'esempio qui sopra, potresti semplificare i test e migliorare le
performance semplicemente spostando `"bar"` in un helper utilizzato da entrambe
`/foo` e `/bar`.

Se vuoi inviare la richiesta alla medesima istanza dell'applicazione piuttosto che
a un duplicato, usa `call!` invece di `call`.

Leggi la specifica Rack se vuoi saperne di più riguardo `call`.

### Definire il Body, lo Status Code e gli Headers

È possibile e raccomandato impostare lo status code e il body di una risposta
con il valore di ritorno del blocco di una route. Tuttavia, in alcuni scenari
potresti avere la necessità di impostare il body arbitrariamente in un qualsiasi punto
del flusso di esecuzione. Puoi farlo con l'helper `body`. Dopo l'utilizzo di questo helper
puoi accedere al body utilizzando lo stesso metodo:

``` ruby
get '/foo' do
  body "bar"
end

after do
  puts body
end
```
È anche possibile passare un blocco al metodo `body`, qusto verrà eseguito
dal Rack handler (questo metodo può essere utilizzato per implementare uno
streaming, vedi "Valori di ritorno").

In modo simile al body puoi anche impostare lo status code e gli headers:

``` ruby
get '/foo' do
  status 418
  headers \
    "Allow"   => "BREW, POST, GET, PROPFIND, WHEN",
    "Refresh" => "Refresh: 20; http://www.ietf.org/rfc/rfc2324.txt"
  body "I'm a tea pot!"
end
```
Come per `body`, anche `headers` e `status` se chiamati senza argomenti sono utilizzabili
per accedere al loro valore attuale.

### Streaming Responses

A volte vuoi iniziare ad inviare i dati mentre stai ancora generando delle parti
del respons body. In casi estremi potresti voler continuare ad inviare dati fino a
quando il client chiude la connessione. Puoi usare l'helper `stream` per evitare
di creare un tuo wrapper:

``` ruby
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
Questo ti permette di implemteare l'API streaming, [Server Sent Events](http://dev.w3.org/html5/eventsource/),
e può essere utilizzato come base per un [WebSockets](http://en.wikipedia.org/wiki/WebSocket).
Può venire utilizzato per incrementare il throughput se alcuni contenut (non tutti) dipendono
da una risorsa lenta.

Nota che il funzionamento di streaming, specialmente il numero di richieste concorrenti,
dipende direttamente dal web server utilizzato per l'applicazione.
Alcuni server , come WEBRick, possono non supportara lo streaming. Se il server
non supporta lo streaming, il body sarà inviato tutti in una volta al momento che l'esecuzione
del blocco passato a `stream` sarà terminata. Lo streaming non funziona con Shotgun.

Se il parametro opzionale e impostato a `keep_open`, non verrà chiamato il metodo
`close` sul oggetto stream, lasciandoti libero di chiudere lo strem in qualsiasi punto
più avanti nel flusso d'esecuzione. Questa funzionalità é disponibile unicamente
con i server "evented" come Thin e Rainbows.
Gli altri servers chiuderanno comunque lo stream:

``` ruby
# long polling

set :server, :thin
connections = []

get '/subscribe' do
  # register a client's interest in server events
  stream(:keep_open) { |out| connections << out }

  # purge dead connections
  connections.reject!(&:closed?)

  # acknowledge
  "subscribed"
end

post '/message' do
  connections.each do |out|
    # notify client that a new message has arrived
    out << params[:message] << "\n"

    # indicate client to connect again
    out.close
  end

  # acknowledge
  "message received"
end
```

### Logging

Nell'ambito della richiesta, il `logger` helper espone un istanza di `Logger`:

``` ruby
get '/' do
  logger.info "loading data"
  # ...
end
```

Questo logger prendera automaticamente in considerazione i settings del tuo
Rack handler. Se il logging é disabilitato, questo metodo ritornerà un oggetto
fittizio, così non dovrai preocupartene nelle tue routes e nei filtri.

Nota che il logging é abilitato di default solamente per `Sinatra::Application`,
Quindi se i tuoi oggetti ereditano da `Sinatra::Base` probabilmente vorrai abilitarlo
manualmente:

``` ruby
class MyApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end
end
```

Per evitare che qualsiasi middleware di loggin venga settato, imposta il
`logging` setting a nil. Un caso comune é quando vuoi utilizzare il tuo
logger personale. Sinatra utilizza qualsiasi cosa che trova in `env['rack.logger']`.


### Mime Types

Quando utilizzi `send_file` o dei files statici potresti avere dei mime types
che Sinatra non può capire. Usa `mime_type` per registrarli secondo la loro estensione:

``` ruby
configure do
  mime_type :foo, 'text/foo'
end
```
Puoi anche utilizzare il `content_type` helper:


``` ruby
get '/' do
  content_type :foo
  "foo foo foo"
end
```

### Generare URLs

Per genrare gli URLs dovresti utilizzare l'helper `url`, per esempio,
in Haml:

``` ruby
%a{:href => url('/foo')} foo
```

In questo modo vengono presi in considerazione i reverse proxy e
le Rack routes se presenti.

Questo helper viene anche utilizzate con l'alias `to`.

### Browser Redirect

Puoi innescare un browser redirect con l'helper `redirect`:er method:

``` ruby
get '/foo' do
  redirect to('/bar')
end
```

Ogni parametro addizionale verrà trattato come un argomento passato ad `halt`:

``` ruby
redirect to('/bar'), 303
redirect 'http://google.com', 'wrong place, buddy'
```

Puoi anche redirectare l'utente alla pagina da cui proviene con `redirect back`:

``` ruby
get '/foo' do
  "<a href='/bar'>do something</a>"
end

get '/bar' do
  do_something
  redirect back
end
```
Per passare degli argomenti con un redirect, aggiungili come query:

``` ruby
redirect to('/bar?sum=42')
```
O usa una sessione:

``` ruby
enable :sessions

get '/foo' do
  session[:secret] = 'foo'
  redirect to('/bar')
end

get '/bar' do
  session[:secret]
end
```

### Gestire la Cache

Impostare correttamente i tuoi headers é fondamentale per un corretto HTTP caching.

Puoi impostare facilmetne il Cache-Control header così:

``` ruby
get '/' do
  cache_control :public
  "cache it!"
end
```

Pro tip: imposta il caching in un before filter:

``` ruby
before do
  cache_control :public, :must_revalidate, :max_age => 60
end
```

Se utlizzi l'helper `expires` per impostare l'header expires, il
`Cache-Control` verrà impostato automaticmante:

``` ruby
before do
  expires 500, :public, :must_revalidate
end
```

Per utilizzare corretamente le caches, dovresti considerare di utilizzare `etag` o `last_modified`.
Si raccomnda di chiamare questi helper *prima* di effettuare operazioni pesanti,
in modo che queste inviino direttamente una response se il client possiede già l'ultima
versione della cache:

``` ruby
get '/article/:id' do
  @article = Article.find params[:id]
  last_modified @article.updated_at
  etag @article.sha1
  erb :article
end
```

Si può anche utilizzare:
[weak ETag](http://en.wikipedia.org/wiki/HTTP_ETag#Strong_and_weak_validation):

``` ruby
etag @article.sha1, :weak
```
QUesti helper non eseguiranno il caching per te, ma ti aiuteranno ad inserire i
dati necessari alla tua cache. Se stai cercando una soluzione veloce per il
reverse-proxy cachins, prova [rack-cache](https://github.com/rtomayko/rack-cache):

``` ruby
require "rack/cache"
require "sinatra"

usa Rack::Cache

get '/' do
  cache_control :public, :max_age => 36000
  sleep 5
  "hello"
end
```

Puoi configurare `:static_cache_control`(vedi sotto) per
aggiungere l'attributo dell'header `Cache-Control` ad
un file statico.

Secondo la specifica RFC 2616, la tua applicazine dovrebbe avere un
comportamento differente se If-Match o If-None-Match sono impostati a
`*` nell'header, a dipendenza se la risorsa richiesta esiste già o meno.
Sinatra assume che le risorse per richieste sicure(come get) e idempotenti(come put)
esistano già, mentre altre risorse(per esempio post) sono trattate come nuove risorse.
Puoi modificare questo comportamento passando l'opzione `:new_resource`:

``` ruby
get '/create' do
  etag '', :new_resource => true
  Article.create
  erb :new_article
end
```

Se vuoi ancora utiizzare un ETag debole, passa l'opzione `:kind`:

``` ruby
etag '', :new_resource => true, :kind => :weak
```

### Inviare Files

Per inviare dei files, puoi utilizzare l'helper `send_file`:

``` ruby
get '/' do
  send_file 'foo.png'
end
```

Accetta anche delle opzioni:

``` ruby
send_file 'foo.png', :type => :jpg
```
Le opzioni sono:

<dl>
  <dt>filename</dt>
    <dd>il nome del file nella risposta, di defaults il nome del file inviato.</dd>

  <dt>last_modified</dt>
    <dd>valore per l'header Last-Modified header, di defaults la data di modifica del file.</dd>

  <dt>type</dt>
    <dd>il content type da utilizzare, viene indovinato dall'estensione del file se non specificato.</dd>

  </dt>disposition</dt>
    <dd>
      utilizzato per Content-Disposition, possibili valori: <tt>nil</tt> (default),
      <tt>:attachment</tt> e <tt>:inline</tt>
    </dd>

  <dt>length</dt>
    <dd>l'header Content-Length, di defaults la dimensione del file.</dd>

  <dt>status</dt>
    <dd>
      Status code da inviare. Utile quando si invia un file statico come error page.

      Se il Rack andler lo supporta, verrano utilizzati sistemi che non sono lo
      streaming del processo Ruby. Se utilizzi questo helper, Sinatra si occuperà
      di gestire le richieste automaticamente.
    </dd>
</dl>

### Accessing the Request Object

The incoming request object can be accessed from request level (filter, routes,
error handlers) through the `request` method:

``` ruby
# app running on http://example.com/example
get '/foo' do
  t = %w[text/css text/html application/javascript]
  request.accept              # ['text/html', '*/*']
  request.accept? 'text/xml'  # true
  request.preferred_type(t)   # 'text/html'
  request.body                # request body sent by the client (see below)
  request.scheme              # "http"
  request.script_name         # "/example"
  request.path_info           # "/foo"
  request.port                # 80
  request.request_method      # "GET"
  request.query_string        # ""
  request.content_length      # length of request.body
  request.media_type          # media type of request.body
  request.host                # "example.com"
  request.get?                # true (similar methods for other verbs)
  request.form_data?          # false
  request["some_param"]       # value of some_param parameter. [] is a shortcut to the params hash.
  request.referrer            # the referrer of the client or '/'
  request.user_agent          # user agent (used by :agent condition)
  request.cookies             # hash of browser cookies
  request.xhr?                # is this an ajax request?
  request.url                 # "http://example.com/example/foo"
  request.path                # "/example/foo"
  request.ip                  # client IP address
  request.secure?             # false (would be true over ssl)
  request.forwarded?          # true (if running behind a reverse proxy)
  request.env                 # raw env hash handed in by Rack
end
```

Some options, like `script_name` or `path_info`, can also be
written:

``` ruby
before { request.path_info = "/" }

get "/" do
  "all requests end up here"
end
```

The `request.body` is an IO or StringIO object:

``` ruby
post "/api" do
  request.body.rewind  # in case someone already read it
  data = JSON.parse request.body.read
  "Hello #{data['name']}!"
end
```

### Attachments

You can use the `attachment` helper to tell the browser the response should be
stored on disk rather than displayed in the browser:

``` ruby
get '/' do
  attachment
  "store it!"
end
```

You can also pass it a file name:

``` ruby
get '/' do
  attachment "info.txt"
  "store it!"
end
```

### Dealing with Date and Time

Sinatra offers a `time_for` helper method that generates a Time object
from the given value. It is also able to convert `DateTime`, `Date` and
similar classes:

``` ruby
get '/' do
  pass if Time.now > time_for('Dec 23, 2012')
  "still time"
end
```

This method is used internally by `expires`, `last_modified` and akin. You can
therefore easily extend the behavior of those methods by overriding `time_for`
in your application:

``` ruby
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

### Looking Up Template Files

The `find_template` helper is used to find template files for rendering:

``` ruby
find_template settings.views, 'foo', Tilt[:haml] do |file|
  puts "could be #{file}"
end
```

This is not really useful. But it is useful that you can actually override this
method to hook in your own lookup mechanism. For instance, if you want to be
able to use more than one view directory:

``` ruby
set :views, ['views', 'templates']

helpers do
  def find_template(views, name, engine, &block)
    Array(views).each { |v| super(v, name, engine, &block) }
  end
end
```

Another example would be using different directories for different engines:

``` ruby
set :views, :sass => 'views/sass', :haml => 'templates', :default => 'views'

helpers do
  def find_template(views, name, engine, &block)
    _, folder = views.detect { |k,v| engine == Tilt[k] }
    folder ||= views[:default]
    super(folder, name, engine, &block)
  end
end
```

You can also easily wrap this up in an extension and share with others!

Note that `find_template` does not check if the file really exists but
rather calls the given block for all possible paths. This is not a performance
issue, since `render` will use `break` as soon as a file is found. Also,
template locations (and content) will be cached if you are not running in
development mode. You should keep that in mind if you write a really crazy
method.

## Configuration

Run once, at startup, in any environment:

``` ruby
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
```

Run only when the environment (`RACK_ENV` environment variable) is set to
`:production`:

``` ruby
configure :production do
  ...
end
```

Run when the environment is set to either `:production` or `:test`:

```ruby
configure :production, :test do
  ...
end
```

You can access those options via `settings`:

``` ruby
configure do
  set :foo, 'bar'
end

get '/' do
  settings.foo? # => true
  settings.foo  # => 'bar'
  ...
end
```

### Configuring attack protection

Sinatra is using
[Rack::Protection](https://github.com/rkh/rack-protection#readme) to defend
your application against common, opportunistic attacks. You can easily disable
this behavior (which will open up your application to tons of common
vulnerabilities):

``` ruby
disable :protection
```

To skip a single defense layer, set `protection` to an options hash:

``` ruby
set :protection, :except => :path_traversal
```
You can also hand in an array in order to disable a list of protections:

``` ruby
set :protection, :except => [:path_traversal, :session_hijacking]
```

By default, Sinatra will only set up session based protection if `:sessions`
has been enabled. Sometimes you want to set up sessions on your own, though. In
that case you can get it to set up session based protections by passing the
`:session` option:

``` ruby
use Rack::Session::Pool
set :protection, :session => true
```

### Available Settings

<dl>
  <dt>absolute_redirects</dt>
  <dd>
    If disabled, Sinatra will allow relative redirects, however, Sinatra will no
    longer conform with RFC 2616 (HTTP 1.1), which only allows absolute redirects.
  </dd>
  <dd>
    Enable if your app is running behind a reverse proxy that has not been set up
    properly. Note that the <tt>url</tt> helper will still produce absolute URLs, unless you
    pass in <tt>false</tt> as the second parameter.
  </dd>
  <dd>Disabled by default.</dd>

  <dt>add_charsets</dt>
  <dd>
    Mime types the <tt>content_type</tt> helper will automatically add the charset info to.
    You should add to it rather than overriding this option:
    <tt>settings.add_charsets << "application/foobar"</tt>
  </dd>

  <dt>app_file</dt>
  <dd>
    Path to the main application file, used to detect project root, views and public
    folder and inline templates.
  </dd>

  <dt>bind</dt>
  <dd>IP address to bind to (default: <tt>0.0.0.0</tt> <em>or</em> <tt>localhost</tt> if your `environment` is set to development.). Only used for built-in server.</dd>

  <dt>default_encoding</dt>
  <dd>Encoding to assume if unknown (defaults to <tt>"utf-8"</tt>).</dd>

  <dt>dump_errors</dt>
  <dd>Display errors in the log.</dd>

  <dt>environment</dt>
  <dd>
    Current environment. Defaults to <tt>ENV['RACK_ENV']</tt>, or <tt>"development"</tt> if
    not available.
  </dd>

  <dt>logging</dt>
  <dd>Use the logger.</dd>

  <dt>lock</dt>
  <dd>
    Places a lock around every request, only running processing on request
    per Ruby process concurrently.
  </dd>
  <dd>Enabled if your app is not thread-safe. Disabled per default.</dd>

  <dt>method_override</dt>
  <dd>
    Use <tt>_method</tt> magic to allow put/delete forms in browsers that
    don't support it.
  </dd>

  <dt>port</dt>
  <dd>Port to listen on. Only used for built-in server.</dd>

  <dt>prefixed_redirects</dt>
  <dd>
    Whether or not to insert <tt>request.script_name</tt> into redirects if no
    absolute path is given. That way <tt>redirect '/foo'</tt> would behave like
    <tt>redirect to('/foo')</tt>. Disabled per default.
  </dd>

  <dt>protection</dt>
  <dd>Whether or not to enable web attack protections. See protection section above.</dd>

  <dt>public_dir</dt>
  <dd>Alias for <tt>public_folder</tt>. See below.</dd>

  <dt>public_folder</dt>
  <dd>
    Path to the folder public files are served from. Only used if static
    file serving is enabled (see <tt>static</tt> setting below). Inferred from
    <tt>app_file</tt> setting if not set.
  </dd>

  <dt>reload_templates</dt>
  <dd>
    Whether or not to reload templates between requests. Enabled in development mode.
  </dd>

  <dt>root</dt>
  <dd>
    Path to project root folder. Inferred from <tt>app_file</tt> setting if not set.
  </dd>

  <dt>raise_errors</dt>
  <dd>
    Raise exceptions (will stop application). Enabled by default when
    <tt>environment</tt> is set to <tt>"test"</tt>, disabled otherwise.
  </dd>

  <dt>run</dt>
  <dd>
    If enabled, Sinatra will handle starting the web server. Do not
    enable if using rackup or other means.
  </dd>

  <dt>running</dt>
  <dd>Is the built-in server running now? Do not change this setting!</dd>

  <dt>server</dt>
  <dd>
    Server or list of servers to use for built-in server. Order indicates
    priority, default depends on Ruby implementation.
  </dd>

  <dt>sessions</dt>
  <dd>
    Enable cookie-based sessions support using <tt>Rack::Session::Cookie</tt>.
    See 'Using Sessions' section for more information.
  </dd>

  <dt>show_exceptions</dt>
  <dd>
    Show a stack trace in the browser when an exception
    happens. Enabled by default when <tt>environment</tt>
    is set to <tt>"development"</tt>, disabled otherwise.
  </dd>
  <dd>
    Can also be set to <tt>:after_handler</tt> to trigger
    app-specified error handling before showing a stack
    trace in the browser.
  </dd>

  <dt>static</dt>
  <dd>Whether Sinatra should handle serving static files.</dd>
  <dd>Disable when using a server able to do this on its own.</dd>
  <dd>Disabling will boost performance.</dd>
  <dd>
    Enabled per default in classic style, disabled for
    modular apps.
  </dd>

  <dt>static_cache_control</dt>
  <dd>
    When Sinatra is serving static files, set this to add
    <tt>Cache-Control</tt> headers to the responses. Uses the
    <tt>cache_control</tt> helper. Disabled by default.
  </dd>
  <dd>
    Use an explicit array when setting multiple values:
    <tt>set :static_cache_control, [:public, :max_age => 300]</tt>
  </dd>

  <dt>threaded</dt>
  <dd>
    If set to <tt>true</tt>, will tell Thin to use <tt>EventMachine.defer</tt>
    for processing the request.
  </dd>

  <dt>views</dt>
  <dd>
    Path to the views folder. Inferred from <tt>app_file</tt> setting if
    not set.
  </dd>

  <dt>x_cascade</dt>
  <dd>
    Whether or not to set the X-Cascade header if no route matches.
    Defaults to <tt>true</tt>.
  </dd>
</dl>

## Environments

There are three predefined `environments`: `"development"`,
`"production"` and `"test"`. Environments can be set
through the `RACK_ENV` environment variable. The default value is
`"development"`. In the `"development"` environment all templates are reloaded between
requests, and special `not_found` and `error` handlers
display stack traces in your browser.
In the `"production"` and `"test"` environments, templates are cached by default.

To run different environments, set the `RACK_ENV` environment variable:

``` shell
RACK_ENV=production ruby my_app.rb
```

You can use predefined methods: `development?`, `test?` and `production?` to
check the current environment setting:

``` ruby
get '/' do
  if settings.development?
    "development!"
  else
    "not development!"
  end
end
```

## Error Handling

Error handlers run within the same context as routes and before filters, which
means you get all the goodies it has to offer, like `haml`,
`erb`, `halt`, etc.

### Not Found

When a `Sinatra::NotFound` exception is raised, or the response's status
code is 404, the `not_found` handler is invoked:

``` ruby
not_found do
  'This is nowhere to be found.'
end
```

### Error

The `error` handler is invoked any time an exception is raised from a route
block or a filter. The exception object can be obtained from the
`sinatra.error` Rack variable:

``` ruby
error do
  'Sorry there was a nasty error - ' + env['sinatra.error'].name
end
```

Custom errors:

``` ruby
error MyCustomError do
  'So what happened was...' + env['sinatra.error'].message
end
```

Then, if this happens:

``` ruby
get '/' do
  raise MyCustomError, 'something bad'
end
```

You get this:

```
So what happened was... something bad
```

Alternatively, you can install an error handler for a status code:

``` ruby
error 403 do
  'Access forbidden'
end

get '/secret' do
  403
end
```

Or a range:

``` ruby
error 400..510 do
  'Boom'
end
```

Sinatra installs special `not_found` and `error` handlers when
running under the development environment to display nice stack traces
and additional debugging information in your browser.

## Rack Middleware

Sinatra rides on [Rack](http://rack.rubyforge.org/), a minimal standard
interface for Ruby web frameworks. One of Rack's most interesting capabilities
for application developers is support for "middleware" -- components that sit
between the server and your application monitoring and/or manipulating the
HTTP request/response to provide various types of common functionality.

Sinatra makes building Rack middleware pipelines a cinch via a top-level
`use` method:

``` ruby
require 'sinatra'
require 'my_custom_middleware'

use Rack::Lint
use MyCustomMiddleware

get '/hello' do
  'Hello World'
end
```

The semantics of `use` are identical to those defined for the
[Rack::Builder](http://rack.rubyforge.org/doc/classes/Rack/Builder.html) DSL
(most frequently used from rackup files). For example, the `use` method
accepts multiple/variable args as well as blocks:

``` ruby
use Rack::Auth::Basic do |username, password|
  username == 'admin' && password == 'secret'
end
```

Rack is distributed with a variety of standard middleware for logging,
debugging, URL routing, authentication, and session handling. Sinatra uses
many of these components automatically based on configuration so you
typically don't have to `use` them explicitly.

You can find useful middleware in
[rack](https://github.com/rack/rack/tree/master/lib/rack),
[rack-contrib](https://github.com/rack/rack-contrib#readm),
with [CodeRack](http://coderack.org/) or in the
[Rack wiki](https://github.com/rack/rack/wiki/List-of-Middleware).

## Testing

Sinatra tests can be written using any Rack-based testing library or framework.
[Rack::Test](http://rdoc.info/github/brynary/rack-test/master/frames)
is recommended:

``` ruby
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

Note: If you are using Sinatra in the modular style, replace `Sinatra::Application`
above with the class name of your app.

## Sinatra::Base - Middleware, Libraries, and Modular Apps

Defining your app at the top-level works well for micro-apps but has
considerable drawbacks when building reusable components such as Rack
middleware, Rails metal, simple libraries with a server component, or even
Sinatra extensions. The top-level assumes a micro-app style configuration
(e.g., a single application file, `./public` and `./views`
directories, logging, exception detail page, etc.). That's where
`Sinatra::Base` comes into play:

``` ruby
require 'sinatra/base'

class MyApp < Sinatra::Base
  set :sessions, true
  set :foo, 'bar'

  get '/' do
    'Hello world!'
  end
end
```

The methods available to `Sinatra::Base` subclasses are exactly the same as those
available via the top-level DSL. Most top-level apps can be converted to
`Sinatra::Base` components with two modifications:

* Your file should require `sinatra/base` instead of `sinatra`;
  otherwise, all of Sinatra's DSL methods are imported into the main
  namespace.
* Put your app's routes, error handlers, filters, and options in a subclass
  of `Sinatra::Base`.

`Sinatra::Base` is a blank slate. Most options are disabled by default,
including the built-in server. See
[Options and Configuration](http://sinatra.github.com/configuration.html)
for details on available options and their behavior.

### Modular vs. Classic Style

Contrary to common belief, there is nothing wrong with the classic style. If it
suits your application, you do not have to switch to a modular application.

The main disadvantage of using the classic style rather than the modular style is that
you will only have one Sinatra application per Ruby process. If you plan to use
more than one, switch to the modular style. There is no reason you cannot mix
the modular and the classic styles.

If switching from one style to the other, you should be aware of slightly
different default settings:

<table>
  <tr>
    <th>Setting</th>
    <th>Classic</th>
    <th>Modular</th>
  </tr>

  <tr>
    <td>app_file</td>
    <td>file loading sinatra</td>
    <td>file subclassing Sinatra::Base</td>
  </tr>

  <tr>
    <td>run</td>
    <td>$0 == app_file</td>
    <td>false</td>
  </tr>

  <tr>
    <td>logging</td>
    <td>true</td>
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

### Serving a Modular Application

There are two common options for starting a modular app, actively starting with
`run!`:

``` ruby
# my_app.rb
require 'sinatra/base'

class MyApp < Sinatra::Base
  # ... app code here ...

  # start the server if ruby file executed directly
  run! if app_file == $0
end
```

Start with:

``` shell
ruby my_app.rb
```

Or with a `config.ru` file, which allows using any Rack handler:

``` ruby
# config.ru (run with rackup)
require './my_app'
run MyApp
```

Run:

``` shell
rackup -p 4567
```

### Using a Classic Style Application with a config.ru

Write your app file:

``` ruby
# app.rb
require 'sinatra'

get '/' do
  'Hello world!'
end
```

And a corresponding `config.ru`:

``` ruby
require './app'
run Sinatra::Application
```

### When to use a config.ru?

A `config.ru` file is recommended if:

* You want to deploy with a different Rack handler (Passenger, Unicorn,
  Heroku, ...).
* You want to use more than one subclass of `Sinatra::Base`.
* You want to use Sinatra only for middleware, and not as an endpoint.

**There is no need to switch to a `config.ru` simply because you
switched to the modular style, and you don't have to use the modular style for running
with a `config.ru`.**

### Using Sinatra as Middleware

Not only is Sinatra able to use other Rack middleware, any Sinatra application
can in turn be added in front of any Rack endpoint as middleware itself. This
endpoint could be another Sinatra application, or any other Rack-based
application (Rails/Ramaze/Camping/...):

``` ruby
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
  # middleware will run before filters
  use LoginScreen

  before do
    unless session['user_name']
      halt "Access denied, please <a href='/login'>login</a>."
    end
  end

  get('/') { "Hello #{session['user_name']}." }
end
```

### Dynamic Application Creation

Sometimes you want to create new applications at runtime without having to
assign them to a constant. You can do this with `Sinatra.new`:

``` ruby
require 'sinatra/base'
my_app = Sinatra.new { get('/') { "hi" } }
my_app.run!
```

It takes the application to inherit from as an optional argument:

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

This is especially useful for testing Sinatra extensions or using Sinatra in
your own library.

This also makes using Sinatra as middleware extremely easy:

``` ruby
require 'sinatra/base'

use Sinatra do
  get('/') { ... }
end

run RailsProject::Application
```

## Scopes and Binding

The scope you are currently in determines what methods and variables are
available.

### Application/Class Scope

Every Sinatra application corresponds to a subclass of `Sinatra::Base`.
If you are using the top-level DSL (`require 'sinatra'`), then this
class is `Sinatra::Application`, otherwise it is the subclass you
created explicitly. At class level you have methods like `get` or `before`, but
you cannot access the `request` or `session` objects, as there is only a
single application class for all requests.

Options created via `set` are methods at class level:

``` ruby
class MyApp < Sinatra::Base
  # Hey, I'm in the application scope!
  set :foo, 42
  foo # => 42

  get '/foo' do
    # Hey, I'm no longer in the application scope!
  end
end
```

You have the application scope binding inside:

* Your application class body
* Methods defined by extensions
* The block passed to `helpers`
* Procs/blocks used as value for `set`
* The block passed to `Sinatra.new`

You can reach the scope object (the class) like this:

* Via the object passed to configure blocks (`configure { |c| ... }`)
* `settings` from within the request scope

### Request/Instance Scope

For every incoming request, a new instance of your application class is
created, and all handler blocks run in that scope. From within this scope you
can access the `request` and `session` objects or call rendering methods like
`erb` or `haml`. You can access the application scope from within the request
scope via the `settings` helper:

``` ruby
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
```

You have the request scope binding inside:

* get, head, post, put, delete, options, patch, link, and unlink blocks
* before and after filters
* helper methods
* templates/views

### Delegation Scope

The delegation scope just forwards methods to the class scope. However, it
does not behave exactly like the class scope, as you do not have the class
binding. Only methods explicitly marked for delegation are available, and you
do not share variables/state with the class scope (read: you have a different
`self`). You can explicitly add method delegations by calling
`Sinatra::Delegator.delegate :method_name`.

You have the delegate scope binding inside:

* The top level binding, if you did `require "sinatra"`
* An object extended with the `Sinatra::Delegator` mixin

Have a look at the code for yourself: here's the
[Sinatra::Delegator mixin](https://github.com/sinatra/sinatra/blob/ca06364/lib/sinatra/base.rb#L1609-1633)
being [extending the main object](https://github.com/sinatra/sinatra/blob/ca06364/lib/sinatra/main.rb#L28-30).

## Command Line

Sinatra applications can be run directly:

``` shell
ruby myapp.rb [-h] [-x] [-e ENVIRONMENT] [-p PORT] [-o HOST] [-s HANDLER]
```

Options are:

```
-h # help
-p # set the port (default is 4567)
-o # set the host (default is 0.0.0.0)
-e # set the environment (default is development)
-s # specify rack server/handler (default is thin)
-x # turn on the mutex lock (default is off)
```

## Requirement

The following Ruby versions are officially supported:
<dl>
  <dt>Ruby 1.8.7</dt>
  <dd>
    1.8.7 is fully supported, however, if nothing is keeping you from it, we
    recommend upgrading or switching to JRuby or Rubinius. Support for 1.8.7
    will not be dropped before Sinatra 2.0. Ruby 1.8.6 is no longer supported.
  </dd>

  <dt>Ruby 1.9.2</dt>
  <dd>
    1.9.2 is fully supported. Do not use 1.9.2p0, as it is known to cause
    segmentation faults when running Sinatra. Official support will continue
    at least until the release of Sinatra 1.5.
  </dd>

  <dt>Ruby 1.9.3</dt>
  <dd>
    1.9.3 is fully supported and recommended. Please note that switching to 1.9.3
    from an earlier version will invalidate all sessions. 1.9.3 will be supported
    until the release of Sinatra 2.0.
  </dd>

  <dt>Ruby 2.0.0</dt>
  <dd>
    2.0.0 is fully supported and recommended. There are currently no plans to drop
    official support for it.
  </dd>

  <dt>Rubinius</dt>
  <dd>
    Rubinius is officially supported (Rubinius >= 2.x). It is recommended to
    <tt>gem install puma</tt>.
  </dd>

  <dt>JRuby</dt>
  <dd>
    The latest stable release of JRuby is officially supported. It is not
    recommended to use C extensions with JRuby. It is recommended to
    <tt>gem install trinidad</tt>.
  </dd>
</dl>

We also keep an eye on upcoming Ruby versions.

The following Ruby implementations are not officially supported but still are
known to run Sinatra:

* Older versions of JRuby and Rubinius
* Ruby Enterprise Edition
* MacRuby, Maglev, IronRuby
* Ruby 1.9.0 and 1.9.1 (but we do recommend against using those)

Not being officially supported means if things only break there and not on a
supported platform, we assume it's not our issue but theirs.

We also run our CI against ruby-head (the upcoming 2.1.0), but we can't
guarantee anything, since it is constantly moving. Expect 2.1.0 to be fully
supported.

Sinatra should work on any operating system supported by the chosen Ruby
implementation.

If you run MacRuby, you should `gem install control_tower`.

Sinatra currently doesn't run on Cardinal, SmallRuby, BlueRuby or any
Ruby version prior to 1.8.7.

## The Bleeding Edge

If you would like to use Sinatra's latest bleeding-edge code, feel free to run your
application against the master branch, it should be rather stable.

We also push out prerelease gems from time to time, so you can do a

``` shell
gem install sinatra --pre
```

to get some of the latest features.

### With Bundler

If you want to run your application with the latest Sinatra, using
[Bundler](http://gembundler.com/) is the recommended way.

First, install bundler, if you haven't:

``` shell
gem install bundler
```

Then, in your project directory, create a `Gemfile`:

```ruby
source 'https://rubygems.org'
gem 'sinatra', :github => "sinatra/sinatra"

# other dependencies
gem 'haml'                    # for instance, if you use haml
gem 'activerecord', '~> 3.0'  # maybe you also need ActiveRecord 3.x
```

Note that you will have to list all your application's dependencies in the `Gemfile`.
Sinatra's direct dependencies (Rack and Tilt) will, however, be automatically
fetched and added by Bundler.

Now you can run your app like this:

``` shell
bundle exec ruby myapp.rb
```

### Roll Your Own

Create a local clone and run your app with the `sinatra/lib` directory
on the `$LOAD_PATH`:

``` shell
cd myapp
git clone git://github.com/sinatra/sinatra.git
ruby -I sinatra/lib myapp.rb
```

To update the Sinatra sources in the future:

``` shell
cd myapp/sinatra
git pull
```

### Install Globally

You can build the gem on your own:

``` shell
git clone git://github.com/sinatra/sinatra.git
cd sinatra
rake sinatra.gemspec
rake install
```

If you install gems as root, the last step should be:

``` shell
sudo rake install
```

## Versioning

Sinatra follows [Semantic Versioning](http://semver.org/), both SemVer and
SemVerTag.

## Further Reading

* [Project Website](http://www.sinatrarb.com/) - Additional documentation,
  news, and links to other resources.
* [Contributing](http://www.sinatrarb.com/contributing) - Find a bug? Need
  help? Have a patch?
* [Issue tracker](http://github.com/sinatra/sinatra/issues)
* [Twitter](http://twitter.com/sinatra)
* [Mailing List](http://groups.google.com/group/sinatrarb/topics)
* IRC: [#sinatra](irc://chat.freenode.net/#sinatra) on http://freenode.net
* [Sinatra Book](http://sinatra-book.gittr.com) Cookbook Tutorial
* [Sinatra Recipes](http://recipes.sinatrarb.com/) Community
  contributed recipes
* API documentation for the [latest release](http://rubydoc.info/gems/sinatra)
  or the [current HEAD](http://rubydoc.info/github/sinatra/sinatra) on
  http://rubydoc.info
* [CI server](http://travis-ci.org/sinatra/sinatra)
