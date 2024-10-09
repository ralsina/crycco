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
    def code_block(node : Markd::Node, entering : Bool)
      lang = node.@fence_language
      # FIXME: maybe make these module globals
      formatter = Tartrazine::Html.new
      lexer = Tartrazine.lexer(lang)
      @output_io << formatter.format(node.text.rstrip, lexer)
    end
  end
end
