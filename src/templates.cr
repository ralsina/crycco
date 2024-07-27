require "crinja"
require "crinja/loader/baked_file_loader"

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
