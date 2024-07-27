# # A Crystal version of docco/pycco/etc.
#
# Import our dependencies
require "./templates"
require "file_utils"
require "markd"

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

    def docs_html
      Markd.to_html(docs)
    end

    def code_html
      %(<pre><code class="#{language["name"]}">#{code}</code></pre>)
    end

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

    # Save the document to a file
    def save(path, format = "html", template = "basic")
      FileUtils.mkdir_p(File.dirname(path))
      template = Templates.get("#{template}.j2")
      File.open(path, "w") do |outf|
        outf << template.render({
          "title"    => File.basename(path),
          "sections" => sections.map(&.to_h),
        })
      end
    end
  end

  # Given a list of source files, Create documents for each one
  def process(sources : Array(String), out_dir : String)
    sources.each do |source|
      doc = Document.new(source)
      out_file = File.join(out_dir, File.basename(source) + ".html")
      doc.save(out_file)
    end
  end

  self.load_languages("data/languages.yml")
end
