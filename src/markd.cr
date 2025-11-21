# This wraps Markd and provides a custom renderer that does
# tartrazine-based codeblocks instead of leaving them to be
# rendered client-side.

require "markd"
require "tartrazine"

module Tartrazine
  def self.md_to_html(source : String, options = Markd::Options.new)
    return "" if source.empty?

    document = Markd::Parser.parse(source, options)
    renderer = HTMLRenderer.new(options)
    renderer.render(document)
  end

  class HTMLRenderer < Markd::HTMLRenderer
    @@formatter : Tartrazine::Html = Tartrazine::Html.new

    def code_block(node : Markd::Node, entering : Bool)
      lang = node.@fence_language
      formatter = @@formatter
      begin
        lexer = Tartrazine.lexer(lang)
      rescue Exception
        # If the lexer is not found, we just use the default one
        # which will not highlight the code.
        lexer = Tartrazine.lexer("text")
      end
      @output_io << formatter.format(node.text.rstrip, lexer)
    end
  end
end
