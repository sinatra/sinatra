# -*- encoding: utf-8 -*-

# Run `rake sinatra-contrib.gemspec` to update the gemspec.
require File.expand_path('../lib/sinatra/contrib/version', __FILE__)
Gem::Specification.new do |s|
  s.name        = "sinatra-contrib"
  s.version     = Sinatra::Contrib::VERSION
  s.description = "Collection of useful Sinatra extensions"
  s.homepage    = "http://github.com/sinatra/sinatra-contrib"
  s.summary     = s.description

  # generated from git shortlog -sn
  s.authors = [
    "Konstantin Haase",
    "Gabriel Andretta",
    "Trevor Bramble",
    "Zachary Scott",
    "Katrina Owen",
    "Nicolas Sanguinetti",
    "Hrvoje Šimić",
    "Masahiro Fujiwara",
    "Rafael Magana",
    "Jack Chu",
    "Ilya Shindyapin",
    "Kashyap",
    "Sumeet Singh",
    "lest",
    "Adrian Pacała",
    "Aish",
    "Andrew Crump",
    "David Asabina",
    "Eliot Shepard",
    "Eric Marden",
    "Gray Manley",
    "Guillaume Bouteille",
    "Jamie Hodge",
    "Kyle Lacy",
    "Martin Frost",
    "Mathieu Allaire",
    "Matt Lyon",
    "Matthew Conway",
    "Meck",
    "Michi Huber",
    "Patricio Mac Adden",
    "Reed Lipman",
    "Samy Dindane",
    "Thibaut Sacreste",
    "Uchio KONDO",
    "Will Bailey",
    "undr"
  ]

  # generated from git shortlog -sne
  s.email = [
    "konstantin.mailinglists@googlemail.com",
    "ohhgabriel@gmail.com",
    "inbox@trevorbramble.com",
    "zachary@zacharyscott.net",
    "katrina.owen@gmail.com",
    "contacto@nicolassanguinetti.info",
    "shime.ferovac@gmail.com",
    "m-fujiwara@axsh.net",
    "raf.magana@gmail.com",
    "jack@jackchu.com",
    "konstantin.haase@gmail.com",
    "ilya@shindyapin.com",
    "kashyap.kmbc@gmail.com",
    "ortuna@gmail.com",
    "e@zzak.io",
    "just.lest@gmail.com",
    "altpacala@gmail.com",
    "aisha.fenton@visfleet.com",
    "andrew.crump@ieee.org",
    "david@supr.nu",
    "eshepard@slower.net",
    "eric.marden@gmail.com",
    "g.manley@tukaiz.com",
    "duffman@via.ecp.fr",
    "jamiehodge@me.com",
    "kylewlacy@me.com",
    "blame@kth.se",
    "mathieuallaire@gmail.com",
    "matt@flowerpowered.com",
    "himself@mattonrails.com",
    "yesmeck@gmail.com",
    "michi.huber@gmail.com",
    "patriciomacadden@gmail.com",
    "rmlipman@gmail.com",
    "samy@dindane.com",
    "thibaut.sacreste@gmail.com",
    "udzura@udzura.jp",
    "will.bailey@gmail.com",
    "undr@yandex.ru"
  ]

  # generated from git ls-files
  s.files = [
    "LICENSE",
    "README.md",
    "Rakefile",
    "ideas.md",
    "lib/sinatra/capture.rb",
    "lib/sinatra/config_file.rb",
    "lib/sinatra/content_for.rb",
    "lib/sinatra/contrib.rb",
    "lib/sinatra/contrib/all.rb",
    "lib/sinatra/contrib/setup.rb",
    "lib/sinatra/contrib/version.rb",
    "lib/sinatra/cookies.rb",
    "lib/sinatra/decompile.rb",
    "lib/sinatra/engine_tracking.rb",
    "lib/sinatra/extension.rb",
    "lib/sinatra/json.rb",
    "lib/sinatra/link_header.rb",
    "lib/sinatra/multi_route.rb",
    "lib/sinatra/namespace.rb",
    "lib/sinatra/reloader.rb",
    "lib/sinatra/respond_with.rb",
    "lib/sinatra/streaming.rb",
    "lib/sinatra/test_helpers.rb",
    "sinatra-contrib.gemspec",
    "spec/capture_spec.rb",
    "spec/config_file/key_value.yml",
    "spec/config_file/key_value.yml.erb",
    "spec/config_file/key_value_override.yml",
    "spec/config_file/missing_env.yml",
    "spec/config_file/with_envs.yml",
    "spec/config_file/with_nested_envs.yml",
    "spec/config_file_spec.rb",
    "spec/content_for/different_key.erb",
    "spec/content_for/different_key.erubis",
    "spec/content_for/different_key.haml",
    "spec/content_for/different_key.slim",
    "spec/content_for/footer.erb",
    "spec/content_for/footer.erubis",
    "spec/content_for/footer.haml",
    "spec/content_for/footer.slim",
    "spec/content_for/layout.erb",
    "spec/content_for/layout.erubis",
    "spec/content_for/layout.haml",
    "spec/content_for/layout.slim",
    "spec/content_for/multiple_blocks.erb",
    "spec/content_for/multiple_blocks.erubis",
    "spec/content_for/multiple_blocks.haml",
    "spec/content_for/multiple_blocks.slim",
    "spec/content_for/multiple_yields.erb",
    "spec/content_for/multiple_yields.erubis",
    "spec/content_for/multiple_yields.haml",
    "spec/content_for/multiple_yields.slim",
    "spec/content_for/passes_values.erb",
    "spec/content_for/passes_values.erubis",
    "spec/content_for/passes_values.haml",
    "spec/content_for/passes_values.slim",
    "spec/content_for/same_key.erb",
    "spec/content_for/same_key.erubis",
    "spec/content_for/same_key.haml",
    "spec/content_for/same_key.slim",
    "spec/content_for/takes_values.erb",
    "spec/content_for/takes_values.erubis",
    "spec/content_for/takes_values.haml",
    "spec/content_for/takes_values.slim",
    "spec/content_for_spec.rb",
    "spec/cookies_spec.rb",
    "spec/decompile_spec.rb",
    "spec/extension_spec.rb",
    "spec/json_spec.rb",
    "spec/link_header_spec.rb",
    "spec/multi_route_spec.rb",
    "spec/namespace/foo.erb",
    "spec/namespace/nested/foo.erb",
    "spec/namespace_spec.rb",
    "spec/okjson.rb",
    "spec/reloader/app.rb.erb",
    "spec/reloader_spec.rb",
    "spec/respond_with/bar.erb",
    "spec/respond_with/bar.json.erb",
    "spec/respond_with/baz.yajl",
    "spec/respond_with/foo.html.erb",
    "spec/respond_with/not_html.sass",
    "spec/respond_with_spec.rb",
    "spec/spec_helper.rb",
    "spec/streaming_spec.rb"
  ]

  s.add_dependency "sinatra",   "~> 1.4.0"
  s.add_dependency "backports", ">= 2.0"
  s.add_dependency "tilt",      "~> 1.3"
  s.add_dependency "rack-test"
  s.add_dependency "rack-protection"
  s.add_dependency "multi_json"

  s.add_development_dependency "rspec", "~> 2.3"
  s.add_development_dependency "haml"
  s.add_development_dependency "erubis"
  s.add_development_dependency "slim"
  s.add_development_dependency "rake"
end
