# # templates.cr
#
# This is the code that handles loading the templates which
# are used to generate the final HTML files. It uses the
# [Crinja](https://straight-shoota.github.io/crinja/)
# template engine.

# The Templates module is a singleton that provides access
# to the templates. The loader will look for templates in
# several places:
# * The `templates/` directory
# * The current directory
# * The templates shipped in the binary itself
#
# It will also try to load it with and without adding the `.j2`
# extension.
#
# You can see the provided templates in
# [Github](https://github.com/ralsina/crycco/tree/main/templates)
# and adapt them to your needs: make a copy and pass it in the
# `-t` option to Crycco.

require "crinja"
require "crinja/loader/baked_file_loader"

# This module bakes the default templates into the binary
# so we don't have to carry them around
module MyBakedTemplateFileSystem
  BakedFileSystem.load("../templates", __DIR__)
end

module Templates
  extend self
  Env = Crinja.new

  Env.loader = Crinja::Loader::ChoiceLoader.new([
    Crinja::Loader::FileSystemLoader.new(["templates/", "."]),
    Crinja::Loader::BakedFileLoader.new(MyBakedTemplateFileSystem),
  ])

  def get(name : String) : Crinja::Template
    Env.get_template(name)
  rescue ex : Crinja::TemplateNotFoundError
    Env.get_template(name + ".j2")
  end
end
