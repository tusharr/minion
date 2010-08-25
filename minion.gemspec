# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{af_minion}
  s.version = "0.1.15.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Orion Henry", "AppFolio Dev Team"]
  s.date = %q{2010-08-24}
  s.description = %q{Super simple job queue over AMQP with modifications from AppFolio Inc.}
  s.email = %q{tushar.ranka@appfolio.com orion@heroku.com}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/minion.rb",
     "lib/minion/handler.rb",
     "spec/base.rb",
     "spec/enqueue_spec.rb"
  ]
  s.homepage = %q{http://github.com/orionz/minion}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{af_minion}
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Super simple job queue over AMQP}
  s.test_files = [
    "spec/base.rb",
     "spec/enqueue_spec.rb",
     "examples/math.rb",
     "examples/sandwich.rb",
     "examples/when.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<amqp>, [">= 0.6.7"])
      s.add_runtime_dependency(%q<bunny>, [">= 0.6.0"])
      s.add_runtime_dependency(%q<json>, [">= 1.2.0"])
    else
      s.add_dependency(%q<amqp>, [">= 0.6.7"])
      s.add_dependency(%q<bunny>, [">= 0.6.0"])
      s.add_dependency(%q<json>, [">= 1.2.0"])
    end
  else
    s.add_dependency(%q<amqp>, [">= 0.6.7"])
    s.add_dependency(%q<bunny>, [">= 0.6.0"])
    s.add_dependency(%q<json>, [">= 1.2.0"])
  end
end