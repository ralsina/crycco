require "crinja"

module Templates
  extend self
  Env = Crinja.new
  Env.loader = Crinja::Loader::FileSystemLoader.new(["templates/", "."])

  def get(name : String) : Crinja::Template
    begin
    Env.get_template(name)
    rescue ex : Crinja::TemplateNotFoundError
      Env.get_template(name + ".j2")
    end
  end
end
