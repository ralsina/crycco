# A Crystal version of docco/pycco/etc.
#
# Import our dependencies
require "markd"
require "file_utils"

module Crycco
  extend self
  VERSION = "0.1.0"

  LANGUAGES = Hash(String, Hash(String, String | Regex)).new

  # FIXME: read from data/languages.yml
  # and add match
  def self.load_languages(file : String)
    LANGUAGES[".cr"] = {
      "name"           => "crystal",
      "comment_symbol" => "#",
      "match"          => /^\s*#\s?/,
    }
  end

  class Section
    property docs : String = ""
    property code : String = ""

    def docs_html
      Markd.to_html(docs)
    end

    def code_html(language)
      %(<pre><code class="#{language["name"]}">#{code}</code></pre>)
    end
  end

  # Given a string of source code, parse out each block of prose
  # and the code that follows it — by detecting which is which,
  # line by line — and then create an individual section for it.
  # Each section is an object with `docs` and `code` properties,
  # which can later be converted to HTML.
  def parse(source : String, lang : Hash) : Array(Section)
    lines = source.split("\n")
    sections = [Section.new]

    # Handle empty files and files with shebangs
    return sections if lines.empty?
    lines.shift if lines[0].starts_with? "#!"

    lines.each do |line|
      if lang["match"].as(Regex).match(line)
        # Break section if we find docs after code
        sections << Section.new unless sections[-1].code.empty?
        line = line.sub(lang["match"], "")
        sections[-1].docs += line + "\n"
        # Also break section if we find a line of dashes (HR in markdown)
        sections << Section.new if /^(---+|===+)$/.match line
      else
        sections[-1].code += "#{line}\n"
      end
    end

    # Sections with no code or docs are pointless.
    sections.reject { |s| s.code.strip.empty? && s.docs.strip.empty? }
  end

  # Given a list of source files, parse each with the proper language
  def process(sources : Array(String), out_dir : String)
    sources.each do |source|
      language = LANGUAGES.fetch(File.extname(source), nil)
      raise "Language not found for extension #{File.extname(source)}" if language.nil?
      sections = parse(File.read(source), language)

      # Destination file
      out_file = File.join(out_dir, File.basename(source) + ".html")
      FileUtils.mkdir_p(File.dirname(out_file))
      File.open(out_file, "w") do |outf|
        outf << sections
      end
    end
  end

  self.load_languages("data/languages.yml")
end
