# # Crycco: A Crystal Remix of Docco.
#
# Crycco is a quick and dirty documentation generator in the mold
# of and directly inspired by [Docco](http://jashkenas.github.com/docco/).
#
# It creates HTML output that displays your comments alongside or
# intermingled with your code. All comments are passed through Markdown
# so they are nicely formatted and all code goes through a syntax
# highlighter before being fed to [templates](templates.cr.html).
#
# Crycco also supports the "literate" variant of languages, where
# everything is a comment except things indented 4 spaces or more,
# which are code. Those files should have a double `.ext.md` extension.
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
# fashion, [**from the YAML itself**](languages.yml.html)
#
# Crycco also will let you do other manipulations on the code and docs,
# like generating "literate YAML" out of YAML and viceversa. It says
# "it will" because [it doesn't yet](TODO.md.html)
#
# One of the best things about Docco in my opinion is that it takes the
# tradition of literate programming and turns it into its minimal
# expression, a tiny, simple tool that does one thing well.
#
# This document is the output of running Crycco on
# [its own source code](https://github.com/ralsina/crycco/blob/main/src/crycco.cr),
# so if you keep reading we'll see how it works (it's short!).
#
# If instead you are interested in the CLI tool, you can check out
# [main.cr](main.cr.html) which is the entry point for the
# command line.
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
require "./collection"
require "./templates"
require "file_utils"
require "html"
require "markd"
require "yaml"

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

  # The `BakedLanguages` class embeds the languages definition file
  # in the actual binary so we don't have to carry it around.
  class BakedLanguages
    extend BakedFileSystem
    bake_file "languages.yml", File.read("src/languages.yml")
  end

  # The description of how to parse a language is stored in
  # [a YAML file](languages.yaml.html)
  # which we read here in `Crycco.load_languages`. If no file is given
  # it defaults to the embedded one.
  #
  # The `match` regex is used to detect if a line is a comment or code.
  def self.load_languages(file : String?)
    if file.nil?
      data = YAML.parse(BakedLanguages.get("/languages.yml"))
    else
      data = YAML.parse(File.read(file))
    end
    data.as_h.each do |ext, lang|
      LANGUAGES[ext.to_s] = {
        "name"   => lang["name"].to_s,
        "symbol" => lang["symbol"].to_s,
        "match"  => /^\s*#{Regex.escape(lang["symbol"].to_s)}\s?/,
      }
    end
  end

  # This matches shebangs and things that only LOOK like comments,
  # such as string interpolations.
  NOT_COMMENT = /(^#!|^\s*#\{)/

  # ## Section
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
    # when passed through itself 😂). Finally, it has to be in a single line because
    # spaces are significant in code fragments.
    def code_html
      %(<pre class="code"><code class="#{language["name"]}">) +
        %(#{HTML.escape(code.lstrip("\n"))}) +
        "</code></pre>"
    end

    # `to_source` regenerates valid source code out of the section. This way if
    # the section was generated by a literate document, we can extract the code
    # and comments from it and save it to a file.
    def to_source : String
      lines = [] of String
      docs.rstrip("\n").split("\n").each do |line|
        lines << "#{language["symbol"]} #{line}"
      end
      lines << code.rstrip("\n")
      lines.join("\n")
    end

    # `to_markdown` converts the section into valid markdown with code blocks
    # for the source code.
    #
    def to_markdown : String
      lines = [] of String
      lines << docs
      lines << "```#{language["name"]}"
      lines << code.rstrip("\n")
      lines << "```"
      lines.join("\n")
    end

    # `to_literate` converts the section into valid markdown with code blocks
    # as indented blocks.
    #
    def to_literate : String
      lines = [] of String
      lines << docs
      lines << ""
      lines += code.split("\n").map { |line| "    #{line}" }
      lines << ""
      lines.join("\n")
    end

    # The `to_h` method is used to turn the section into something that can be
    # handled by the Crinja template engine. Just takes the data and put it in
    # a hash.
    def to_h : Hash(String, String)
      {
        "docs"      => docs,
        "code"      => code,
        "docs_html" => docs_html,
        "code_html" => code_html,
        "source"    => to_source,
        "markdown"  => to_markdown,
        "literate"  => to_literate,
      }
    end
  end

  # ## Document
  # A Document takes a path as input and reads the file,
  # parses its contents and is able to generate whatever
  # output is needed.
  class Document
    property path : Path
    property sections = Array(Section).new
    property language : Language
    @literate : Bool = false
    @template : String
    @mode : String

    # On initialization we read the file and parse it in the correct
    # language. Also, if rather than a `.yml` file we have a `.yml.md`
    # we consider that "literate YAML" and tweak the language
    # definition a bit.
    def initialize(@path : Path,
                   @template : String = "sidebyside",
                   @mode : String = "docs")
      key = @path.extension
      if key == ".md" # It may be literate!
        lang_key = File.extname(@path.basename(".md"))
        if LANGUAGES.has_key?(lang_key)
          key = lang_key
          @literate = true
        end
      end

      raise Exception.new "Unknown language for file #{@path}" \
        unless LANGUAGES.has_key? key
      @language = LANGUAGES[key].clone

      # In the literate versions, everything is doc except
      # indented things, which are code. So we change the
      # match regex to match everything except 4 spaces or a tab.
      @language["match"] = /^(?![ ]{4}|\t).*/ if @literate
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

      # This loop is the core of the parser. It goes line by line
      # and decides if the line is a comment or code, and depending
      # on that either starts a new section, or adds to the current
      # one.
      is_comment = language["match"].as(Regex)
      lines.each do |line|
        if is_comment.match(line) && !NOT_COMMENT.match(line)
          # Break section if we find docs after code
          @sections << Section.new(language) unless sections[-1].code.empty?
          # Remove comment markers if it's not literate
          # and stick the line at the end of the current section's
          # docs
          line = line.sub(language["match"], "") unless @literate
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
    # and template. If you want to learn more about the templates
    # you can check out [templates.cr](templates.cr.html)
    #
    def save(out_file : Path, extra_context)
      FileUtils.mkdir_p(File.dirname(path))
      case @mode
      when "markdown"
        template = Templates.get("markdown")
      when "code"
        template = Templates.get("source")
      when "literate"
        template = Templates.get("literate")
      else
        template = Templates.get(@template)
      end

      FileUtils.mkdir_p(File.dirname(out_file))
      File.open(out_file, "w") do |outf|
        outf << template.render({
          "title"    => File.basename(path),
          "sections" => sections.map(&.to_h),
          "language" => language["name"],
        }.merge extra_context)
      end
    end
  end
end

# 🏁 That's it!
