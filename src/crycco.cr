# # Crycco: A Crystal Remix of Docco.
#
# Crycco is a quick and dirty documentation generator in the mold
# of and directly inspired by [Docco](http://jashkenas.github.com/docco/).
#
# It creates HTML output that displays your comments alongside or
# intermingled with your code. All comments are passed through Markdown
# so they are nicely formatted and all code goes through a syntax
# highlighter before being fed to [[templates]].
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
# fashion, [[languages.yml|**from the YAML itself**]]
#
# Crycco also will let you do other manipulations on the code and docs,
# like generating "literate YAML" out of YAML and viceversa. It says
# "it will" because [[TODO.md|it doesn't yet]]
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
# [[main.cr]] which is the entry point for the
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
require "./markd"
require "./templates"
require "./ctags"
require "enum_state_machine"
require "file_utils"
require "html"
require "tartrazine"
require "tartrazine/formatters/html"
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
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

  # Languages are defined in a hash with the extension as the key
  #
  # Each one contains the data required to parse a document in that
  # language, such as the comment symbol and a regex to match it.

  # The Language class holds the definition for a programming language.
  # It's deserialized from the languages.yml file.
  class Language
    include YAML::Serializable

    property name : String
    property symbol : String
    property enclosing_symbol : Array(String) = [] of String
    property? literate : Bool = false

    # This regex is used to identify comment lines.
    # It's derived from `symbol` or can be overridden (e.g., for literate mode).
    # Because it's not serialized in the YAML file we have to say `ignore: true`
    # and set it to a dummy value. It's properly configured in `after_initialize`
    @[YAML::Field(ignore: true)]
    property match : Regex = /.*/

    @[YAML::Field(ignore: true)]
    property match_enclosing_start : Regex = /$^/
    @[YAML::Field(ignore: true)]
    property match_enclosing_end : Regex = /$^/

    # This hook is called after properties are set during YAML deserialization
    # or after `new` with named arguments.
    def after_initialize
      # We consider lines with spaces and then the comment marker as
      # comments.
      @match = /^\s*#{Regex.escape(self.symbol)}\s?/
      if @enclosing_symbol.size == 2
        # If the language supports enclosing comments, then
        # we set those regexes too.
        @match_enclosing_start = /^\s*#{Regex.escape(@enclosing_symbol[0])}\s?/
        @match_enclosing_end = /^\s*#{Regex.escape(@enclosing_symbol[1])}\s?/
      end
    end
  end

  # The `BakedLanguages` class embeds the languages definition file
  # in the actual binary so we don't have to carry it around.
  class BakedLanguages
    extend BakedFileSystem
    bake_file "languages.yml", {{ read_file "#{__DIR__}/languages.yml" }}
  end

  LANGUAGES = Hash(String, Language).new

  # Track all processed files for smart file reference resolution. This
  # global state allows the smart matching algorithm to work across
  # all files in the documentation set.
  @@all_files = [] of Path
  @@base_dir = Path["."]

  # Crycco supports ctags to find where a symbol like a class or
  # function is defined, for easy linking to it.
  @@ctags_manager : CtagsManager?

  def self.all_files
    @@all_files
  end

  def self.all_files=(files : Array(Path))
    @@all_files = files
  end

  def self.base_dir
    @@base_dir
  end

  def self.base_dir=(dir : Path)
    @@base_dir = dir
  end

  def self.ctags_manager
    @@ctags_manager
  end

  def self.ctags_manager=(manager : CtagsManager?)
    @@ctags_manager = manager
  end

  # The description of how to parse a language is stored in
  # [[languages.yml|a YAML file]]
  # which we read here in `Crycco.load_languages`. If no file is given
  # it defaults to the embedded one.
  #
  def self.load_languages(file : String?)
    yaml_string = if file.nil?
                    BakedLanguages.get("languages.yml")
                  else
                    File.read(file)
                  end

    # Merge the data from the file into the LANGUAGES constant
    LANGUAGES.merge! Hash(String, Language).from_yaml(yaml_string)
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
    property path : Path
    @lexer : Tartrazine::Lexer
    @formatter : Tartrazine::Html

    # On initialization we get the language definition and create a lexer
    # and formatter for code highlighting.
    def initialize(@language : Language, @path : Path)
      @lexer = Tartrazine.lexer(@language.name)
      @formatter = Tartrazine::Html.new
      @formatter.line_numbers = false
      @formatter.wrap_long_lines = false
      @formatter.tab_width = 4
    end

    # Smart File References
    #
    # Crycco lets you reference other files with a custom notation.
    #
    # For example, you can reference main.cr like this: `[[main.cr]]`,
    # and it will be converted to a proper HTML link to the documentation.
    #
    # For a custom text other than the filename, you can use `[[main.cr|the main file]]`.

    def process_file_references(text : String) : String
      # First, protect code spans (content between backticks) from processing
      code_spans = [] of String
      text = text.gsub(/`[^`]+`/) do |match|
        code_spans << match
        "__CODE_SPAN_#{code_spans.size - 1}__"
      end

      # Process smart references on the text with code spans protected
      text = text.gsub(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/) do |match|
        if match.includes?("|")
          # Has custom display text: [[filename|text]]
          parts = match[2..-3].split("|", 2)
          ref_with_fragment = parts[0]
          display_text = parts[1]? || ref_with_fragment
        else
          # Simple reference: [[filename]]
          ref_with_fragment = match[2..-3]
          display_text = ref_with_fragment
        end

        # Separate file reference from fragment
        if ref_with_fragment.includes?("#")
          file_ref, fragment = ref_with_fragment.split("#", 2)
        else
          file_ref = ref_with_fragment
          fragment = nil
        end

        if resolved_path = resolve_file_reference(file_ref)
          full_path = fragment ? "#{resolved_path}##{fragment}" : resolved_path
          "[#{display_text}](#{full_path})"
        else
          match # Keep original if resolution fails
        end
      end

      # Restore the original code spans
      code_spans.each_with_index do |span, index|
        text = text.gsub("__CODE_SPAN_#{index}__", span)
      end

      text
    rescue ex
      text
    end

    # To make it even simpler you don't need to use the exact path. As
    # long as the filename is unique among all processed files, Crycco
    # will find it for you. It will also match symbols, such as classes
    # and functions, if you have ctags data available.

    def resolve_file_reference(ref_name : String) : String?
      # First, try as a relative path (already has directory components)
      if ref_name.includes?("/")
        candidate = Path.new(ref_name)
        return html_path_for_file(candidate) if file_exists?(candidate)
      end

      # Try smart matching against all processed files
      matches = [] of Path

      Crycco.all_files.each do |file_path|
        # Exact filename match
        if file_path.basename.to_s == ref_name
          matches << file_path
          # Basename match without extension
        elsif file_path.stem == ref_name
          matches << file_path
        end
      end

      # Return unique match, or nil if ambiguous/not found
      case matches.size
      when 0
        # No file matches - try symbol resolution
        resolve_symbol_reference(ref_name)
      when 1
        html_path_for_file(matches[0])
      else
        # Multiple matches - be smart about prioritization
        # Prefer files in same directory first
        same_dir_matches = matches.select { |file_path| file_path.dirname == @path.dirname }
        if same_dir_matches.size == 1
          html_path_for_file(same_dir_matches[0])
        else
          # Ambiguous file matches - try symbol resolution
          resolve_symbol_reference(ref_name)
        end
      end
    end

    # Symbol Resolution
    #
    # This method handles symbol resolution using ctags. When a reference
    # doesn't match any files, it tries to resolve it as a symbol using
    # the CtagsManager. This enables references like [[ClassName]] or
    # [[method_name]] to link directly to the symbol definition.
    #
    # Symbol resolution follows this priority:
    # 1. Symbols in the current file
    # 2. Unique symbols across all files
    # 3. Returns nil if ambiguous or not found

    def resolve_symbol_reference(symbol_name : String) : String?
      return nil unless ctags_manager = Crycco.ctags_manager

      if result = ctags_manager.resolve_symbol(symbol_name, @path)
        file_path, line_number = result
        html_path = html_path_for_file(file_path)
        "#{html_path}#line-#{line_number}"
      else
        nil
      end
    end

    # HTML Path Generation
    #
    # Once we've resolved a file reference to an actual file, we need to
    # convert that file path to the corresponding HTML documentation path.

    def html_path_for_file(file_path : Path) : String
      relative_path = file_path.relative_to(Crycco.base_dir).to_s
      # Always append .html to match how dst_path works in Collection
      # This ensures consistency between where files are saved and where links point
      relative_path + ".html"
    end

    # Check if a file exists in the processed files list
    def file_exists?(file_path : Path) : Bool
      Crycco.all_files.any? { |processed_file| processed_file.expand == file_path.expand }
    end

    # Extract the first header from documentation for semantic anchoring
    def anchor : String
      # Look for the first header line in the raw documentation text
      # Headers are lines that start with comment marker + # + header text
      comment_marker = @language.symbol

      docs.each_line do |line|
        if line =~ /^\s*#{Regex.escape(comment_marker)}\s*#\s+(.+)$/
          header_text = $1.strip
          # Convert header text to a valid URL anchor:
          # 1. Downcase
          # 2. Replace non-alphanumeric chars with hyphens
          # 3. Remove multiple consecutive hyphens
          # 4. Remove leading/trailing hyphens
          anchor = header_text.downcase
            .gsub(/[^a-z0-9\s-]/, "")
            .gsub(/\s+/, "-")
            .gsub(/-+/, "-")
            .gsub(/^-|-$/, "")

          return anchor.empty? ? "section" : anchor
        end
      end

      "section" # fallback for sections without headers
    end

    # Converting Documentation to HTML
    #
    # The `docs_html` method is responsible for converting the documentation
    # portion of each section into final HTML output. This is where the
    # smart file reference processing happens.
    #
    # The process is:
    # 1. Process any smart file and symbol references (convert `[[file]]` and `[[Symbol]]` to proper links)
    # 2. Convert the resulting Markdown to HTML using Markd
    #
    # This means that writers can use both Markdown syntax AND smart file/symbol
    # references in their documentation comments, and they'll both be handled
    # correctly in the final output.
    #
    # You can see the implementation details of the Markdown processing
    # in [[markd.cr]] and the smart reference processing in the `process_file_references`
    # method above.
    #
    def docs_html
      processed_docs = process_file_references(docs)
      Tartrazine.md_to_html(processed_docs)
    end

    # All the code is passed through the formatter to get syntax highlighting
    def code_html
      if code.strip("\n").empty?
        return ""
      end

      formatted_code = @formatter.format(code.strip("\n"), @lexer)

      # Add line number anchors for symbol linking
      # We wrap each line in a span with an id that can be referenced
      lines = formatted_code.split('\n')
      lines_with_anchors = lines.map_with_index do |line, index|
        line_number = index + 1
        "<span id=\"line-#{line_number}\">#{line}</span>"
      end

      lines_with_anchors.join('\n')
    end

    # `to_source` regenerates valid source code out of the section. This way if
    # the section was generated by a literate document, we can extract the code
    # and comments from it and save it to a file.
    def to_source : String
      lines = [] of String
      docs.rstrip("\n").split("\n").each do |line|
        lines << "#{@language.symbol} #{line}"
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
      lines << "```#{@language.name}"
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
        "anchor"    => anchor,
      }
    end
  end

  # ## Document
  # A Document takes a path as input and reads the file,
  # parses its contents and is able to generate whatever
  # output is needed.
  class Document
    # We include the EnumStateMachine module for the parser
    include EnumStateMachine

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
      @language = Language.from_yaml(LANGUAGES[key].to_yaml)

      # In the literate versions, everything is doc except
      # indented things, which are code. So we change the
      # match regex to match everything except 4 spaces or a tab.
      if @literate
        @language.match = /^(?![ ]{4}|\t).*/
      end
      parse(File.read(@path))
    end

    # Documents are parsed using a state machine, these are the states:
    enum State
      CommentBlock
      EnclosingCommentBlock
      CodeBlock
    end

    # These are the transitions between states:
    state_machine State, initial: State::CodeBlock do
      event :comment, from: [State::CodeBlock], to: State::CommentBlock
      event :enclosing_comment_start, from: [State::CodeBlock], to: State::EnclosingCommentBlock
      event :enclosing_comment_end, from: [State::EnclosingCommentBlock], to: State::CodeBlock
      event :code, from: [State::CommentBlock], to: State::CodeBlock
    end

    # The `parse` method is the core of the Document class. It scans
    # the document line by line, checks if the line is a comment or code
    # and organizes the contents into sections.

    def parse(source : String)
      lines = source.split("\n")
      @sections = [Section.new(@language, @path)]
      # Section.new language
      is_comment = @language.match
      is_enclosing_start = @language.match_enclosing_start
      is_enclosing_end = @language.match_enclosing_end

      lines.each do |line|
        # If the line starts with a comment marker, tell the state machine
        processed_line = line.rstrip

        if is_comment.match(line) && !NOT_COMMENT.match(line)
          self.comment {
            # These blocks only execute when transitions are successful.
            #
            # So, this block is executed when we are transitioning
            # to a comment block, which means we are starting
            # a new section
            @sections << Section.new(@language, @path)
          }
          # Because the docs section is supposed to be markdown, we need
          # to remove the comment marker from the line.
          processed_line = processed_line.sub(@language.match, "") unless @literate
        elsif line.strip.empty?
          self.code
        elsif is_enclosing_start.match(line)
          # If the line starts with an enclosing comment marker
          self.enclosing_comment_start {
            # We are transitioning to an enclosing comment block, so it's
            # a new section too.
            @sections << Section.new(@language, @path)
            processed_line = processed_line.sub(@language.@match_enclosing_start, "") unless @literate
          }
        elsif is_enclosing_end.match(line)
          # The end of an enclosing comment block means we are back to code
          self.enclosing_comment_end
        else
          # Just a normal line.
          self.code
        end

        # If we are in a code block, we add the line to the current section's code
        if state == State::CodeBlock
          @sections.last.code += "#{processed_line}\n"
        else
          # Or, we are in a comment block, and we add the line to the current
          # section's docs
          @sections.last.docs += "#{processed_line}\n"

          # But if the line is a HR, we start a new section
          if /^(---+|===+)$/.match processed_line
            @sections << Section.new(language, @path)
          end
        end
      end

      # Sections with no code or docs are pointless.
      @sections.reject! { |section| section.code.strip.empty? && section.docs.strip.empty? }
    end

    # Save the document to a file using the desired format
    # and template. If you want to learn more about the templates
    # you can check out [[templates.cr]]
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
          "language" => @language.name,
        }.merge extra_context)
      end
    end
  end
end

# 🏁 That's it!
