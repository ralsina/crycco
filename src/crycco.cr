# # Crycco: A Crystal Remix of Docco.
#
# Crycco is a quick and dirty documentation generator in the mold
# of and directly inspired by [Docco](http://jashkenas.github.com/docco/).
#
# It creates HTML output that displays your comments alongside or
# intermingled with your code. All comments are passed through Markdown
# so they are nicely formatted and all code goes through a syntax
# highlighter.
#
# It's a very simple tool but it can be used to good effect in a number
# of situations. Consider a tool that uses a YAML file as configuration.
#
# Usually, one would have to write a README file to explain the format
# of the config file, or worse, have the user read the YAML file itself
# which will have a bunch of comments in there.
#
# With crycco (or docco, or one of its many offshoots) you can generate
# a nice HTML file that explains the config file in a much more readable
# fashion, **from the YAML itself**
#
# Crycco also will let you do other manipulations on the code and docs,
# like generating "literate YAML" which is a markdown file with the YAML
# interspersed within the prose.
#
# One of the best things about Docco in my opinion is that it takes the
# tradition of literate programming and turns it into its minimal
# expression, a tiny, simple tool that does one thing well.
#
# This document is the output of running Crycco on its own source code,
# so if you keep reading it should explain how it works.
#
# ----
#
# # crycco.cr
#
# This is the main file of the project. It contains the main logic
# for parsing the source files and generating the output.
#
# ----
# Import our dependencies
require "./templates"
require "file_utils"
require "html"
require "markd"

# In Crystal it's good to use modules to namespace the code. Specially since
# Crycco also works as a library!
#
# You can add it to a project and use it by adding it as a dependency in `shard.yml`
#
# ```yaml
# dependencies:
#   crycco:
#     github: ralsina/crycco
# ```
#
# And then in your code just `require "crycco"` and use it. I intend to do it in my
# [Nicolino](https://nicolino.ralsina.me) project.
#
# For an example of how to use it, you can look at the `process` method at the end
# of this file.
module Crycco
  extend self
  VERSION = "0.1.0"

  # Languages are defined in a hash with the extension as the key
  #
  # Each one contains the data required to parse a document in that
  # language, such as the comment symbol and a regex to match it.

  alias Language = Hash(String, String | Regex)
  LANGUAGES = Hash(String, Language).new

  # FIXME: read from data/languages.yml
  # and add match
  def self.load_languages(file : String)
    LANGUAGES[".cr"] = {
      "name"           => "crystal",
      "comment_symbol" => "#",
      "match"          => /^\s*#\s?/,
    }
  end

  # Document contents are organized in sections, which have docs and code.
  # The docs are markdown extracted from comments and the code is the actual code.
  #
  # Sections can be converted to HTML using the `docs_html` and `code_html` methods.
  class Section
    property docs : String = ""
    property code : String = ""
    property language : Language

    def initialize(@language : Language)
    end

    # `docs_html` converts the docs to HTML using the Markd library
    def docs_html
      Markd.to_html(docs)
    end

    # Since the generated HTML uses HighlightJS, we need to wrap the code in
    # a `<pre><code>` block with the right class so it's properly highlighted.
    #
    # It should also have the HTML escaped (or else this function would nest two pre tags
    # when passed through itself 😂)
    def code_html
      %(<pre class="code"><code class="#{language["name"]}">#{HTML.escape(code.lstrip("\n"))}</code></pre>)
    end

    # Te `to_h` method is used to turn the section into something that can be
    # handled by the Crinja template engine. Just takes the data and put it in
    # a hash.
    def to_h : Hash(String, String)
      {
        "docs"      => docs,
        "code"      => code,
        "docs_html" => docs_html,
        "code_html" => code_html,
      }
    end
  end

  # A Document takes a path as input and reads the file,
  # parses its contents and is able to generate whatever
  # output is needed.
  class Document
    property path : String
    property sections = Array(Section).new
    property language : Language

    # On initialization we read the file and parse it in the correct
    # language
    def initialize(@path : String)
      key = File.extname(@path)
      raise "Language not found for extension #{File.extname(@path)}" unless LANGUAGES.has_key?(key)
      @language = LANGUAGES[key]

      parse(File.read(@path))
    end

    # Given a string of source code, parse out each block of prose
    # and the code that follows it — by detecting which is which,
    # line by line — and then create an individual section for it.
    # Each section is an object with `docs` and `code` properties,
    # which can later be converted to HTML.
    def parse(source : String)
      lines = source.split("\n")
      @sections = [Section.new language]

      # Handle empty files and files with shebangs
      return if lines.empty?
      lines.shift if lines[0].starts_with? "#!"

      # This loop is the core of the parser. It goes line by line
      # and decides if the line is a comment or code, and depending
      # on that either starts a new section, or adds to the current one.
      lines.each do |line|
        if language["match"].as(Regex).match(line)
          # Break section if we find docs after code
          @sections << Section.new(language) unless sections[-1].code.empty?
          line = line.sub(language["match"], "")
          @sections[-1].docs += line + "\n"
          # Also break section if we find a line of dashes (HR in markdown)
          @sections << Section.new(language) if /^(---+|===+)$/.match line
        else
          @sections[-1].code += "#{line}\n"
        end
      end
      # Sections with no code or docs are pointless.
      @sections.reject! { |section| section.code.strip.empty? && section.docs.strip.empty? }
    end

    # Save the document to a file using the desired format
    # and template.
    def save(out_file, format = "html", template = "sidebyside")
      FileUtils.mkdir_p(File.dirname(path))
      template = Templates.get("#{template}")
      puts "#{self.path} -> #{out_file}"
      FileUtils.mkdir_p(File.dirname(out_file))
      File.open(out_file, "w") do |outf|
        outf << template.render({
          "title"    => File.basename(path),
          "sections" => sections.map(&.to_h),
        })
      end
    end
  end

  # The `process` function is the entry point to the whole thing.
  #
  # Given a list of source files, create documents for each one
  # and save them to the output directory.
  def process(sources : Array(String), out_dir : String, template : String)
    sources.each do |source|
      doc = Document.new(source)
      out_file = File.join(out_dir, File.basename(source) + ".html")
      doc.save(out_file, template: template)
    end
  end

  self.load_languages("data/languages.yml")
end
