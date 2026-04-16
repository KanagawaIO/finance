Gem::Specification.new do |s|
  s.name        = "kanagawa"
  s.version     = "0.1.0"
  s.authors     = [ "Kanagawa" ]
  s.summary     = "Kanagawa extensions for Sure"
  s.files       = Dir["{app,config,db,lib}/**/*", "Rakefile"]
  s.require_paths = [ "lib" ]

  s.add_dependency "rails", ">= 7.2"
  s.add_dependency "sqlite3"
end
