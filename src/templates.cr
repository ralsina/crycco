require "crinja"

module Templates
  extend self
  Env = Crinja.new
  Env.loader = Crinja::Loader::FileSystemLoader.new("templates/")

  def get(name : String) : Crinja::Template
    Env.get_template(name)
  end
end
