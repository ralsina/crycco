# A Crystal version of docco/pycco/etc.
#
# Import our dependencies
require "markd"
require "file_utils"
require "./resources"

module Crycco
  extend self
  VERSION = "0.1.0"

  # FIXME: make this external data
  # FIXME: support multiline comments
  LANGUAGES = {
    ".cr" => {"name" => "crystal", "comment_symbol" => "#"},
  }

  # Generate the documentation for a source file by reading
  # it in, splitting it up into comment/code sections,
  # and merging them into an HTML template.
  def self.generate_documentation(
    source, outdir : String, preserve_paths = true, language = nil
  )
    code = File.read(source)
    _generate_documentation(source, code, outdir, preserve_paths, language)
  end

  def self._generate_documentation(file_path, code, outdir, preserve_paths, language)
    # Helper to allow documentation generation without file handling
    language = get_language(file_path, code, language_name: language)
    sections = parse(code, language)
    highlight(sections, language, preserve_paths: preserve_paths, outdir: outdir)
    generate_html(file_path, sections, preserve_paths: preserve_paths, outdir: outdir)
  end

  def matches_comment?(line, language) : Regex::MatchData | Nil
    # Check if a line of code is a comment
    /^\s*#{language["comment_symbol"]}\s?/.match(line)
  end

  # Given a string of source code, parse out each comment and the code
  # that follows it, and create an individual **section** for it.
  #
  # Sections take the form:
  # ```
  # {"docs_text" => ...,
  #  "docs_html" => ...,
  #  "code_text" => ...,
  #  "code_html" => ...,
  #  "num"       => ...,
  # }
  # ```
  def self.parse(code, language)
    lines = code.split("\n")
    sections = [] of Hash(String, String)

    in_docs = matches_comment?(lines[0], language)
    code_text = docs_text = ""

    lines.each do |line|
      if matches_comment?(line, language)
        if !in_docs
          # We were in a code section, push the previous section
          # and start a new one
          sections.push({
            "docs_text" => docs_text.rstrip,
            "code_text" => code_text.rstrip.lstrip("\n"),
          })
          in_docs = true
          code_text = ""
          docs_text = line.gsub(/^\s*#{language["comment_symbol"]}\s?/, "") + "\n"
        else
          # In a docs section, just append to the docs
          docs_text += line.gsub(/^\s*#{language["comment_symbol"]}\s?/, "") + "\n"
        end
      else # Doesn't match comment, we are in code
        in_docs = false
        code_text += line + "\n"
      end
    end
    sections.push({
      "docs_text" => docs_text.rstrip,
      "code_text" => code_text.rstrip.lstrip("\n"),
    })
    sections.reject! { |section|
      section["docs_text"].empty? && section["code_text"].empty?
    }
  end

  # === Preprocessing the comments ===

  # Add cross-references before having the text processed by markdown.
  # It's possible to reference another fiile, like this: `[[main.py]]`
  # which rendewrs [[main.py]]. You can also reference a specific
  # section of anbother file like this: `[[main.py#highlighting-the-source-code]]`
  # which renders as [[main.py#highlighting-the-source-code]].
  # Sections have to be manually declared; they are written on a single line,
  # and surrounded by equals signs:
  # `=== like this ===`

  def self.preprocess(comment, preserve_paths = true, outdir = nil)
    sanitize_section_name = ->(name : String) : String {
      (name.downcase.strip.split(" ")).join("-")
    }

    # Replace sections with markdown headings
    comment = comment.gsub(/^([=]+)([^=]+)[=]*\s*$/) do |_|
      match = /^([=]+)([^=]+)[=]*\s*$/.match comment
      return "" unless match
      lvl = match[1].gsub("=", "#")
      id = sanitize_section_name.call(match[2])
      name = match[2]
      result = %(#{lvl} <span id="#{id}" href="#{id}">#{name}</span>)
      result
    end

    # Replace cross-references with markdown links
    comment = comment.gsub(/(?<!`)\[\[(.+?)\]\]/) do |_|
      # Check if the match contains an anchor
      match = /(?<!`)\[\[(.+?)\]\]/.match comment
      return "" unless match
      if match[1].includes? "#"
        name, anchor = match[1].split "#"
        path = File.basename(destination(name, preserve_paths: preserve_paths, outdir: outdir))
        " [#{name}](#{path}##{anchor})"
      else
        path = File.basename(destination(match[1], preserve_paths: preserve_paths, outdir: outdir))
        " [#{match[1]}](#{path})"
      end
    end
    comment
  end

  # === Processing text into HTML ===

  # Pass docs via preprocessor and then from markdown to HTML
  # Code just put fences around and pass through markdown to HTML too

  def highlight(sections, language, preserve_paths : Bool, outdir : String)
    sections.each_with_index do |section, i|
      section["docs_html"] = Markd.to_html(
        preprocess(section["docs_text"], preserve_paths: preserve_paths, outdir: outdir)
      )
      section["num"] = i.to_s
      section["code_html"] = Markd.to_html(
        "```#{language["name"]}\n#{section["code_text"]}\n```"
      )
    end
  end

  # === HTML Code generation ===
  
  # Generate the HTML file and write out the documentation. Pass
  # the completed sections into the template found in
  # `resources/pycco.html`
  #
  # Crustache will attempt to recursively render context variables,
  # so we must replace any occurences of `{{`, which is valid in some
  # languages, with a "unique enough" identifier before rendering and
  # then post-process the output to restore the `{{`s.

  def self.generate_html(source, sections, preserve_paths : Bool, outdir : String)
    title = File.basename(source)
    dest = destination(source, preserve_paths: preserve_paths, outdir: outdir)
    css_path = Path[File.join(outdir, "crycco.css")].relative_to(File.dirname(dest)).to_s

    sections.each do |sect|
      sect["code_html"] = sect["code_html"].gsub("{{", "__DOUBLE_OPEN_STACHE__")
    end

    rendered = render_with_template({
      "title"      => title,
      "stylesheet" => css_path,
      "sections"   => sections,
      "source"     => source,
    })
    rendered.gsub("__DOUBLE_OPEN_STACHE__", "{{}")
    rendered
  end

  # === Helpers & Setup ===

  # Get the current language we're documenting, based on the extension
  def self.get_language(source, code, language_name = nil)
    if language_name
      return LANGUAGES[language_name]
    end
    if source
      ext = File.extname(source)
      return LANGUAGES[ext]
    end
    raise Exception.new("Could not determine language")
  rescue KeyError
    if language_name
      raise Exception.new("Language not supported: #{language_name}")
    else
      raise Exception.new("Language not supported: #{ext}")
    end
  end

  # Compute the destination HTML path for an input source file path.
  # If the source is `lib/example.py`, the HTML will be at `docs/example.html`.
  def self.destination(filepath, preserve_paths : Bool, outdir : String)
    dirname = File.dirname(filepath)
    basename = File.basename(filepath)
    return File.join(dirname, "#{basename}.html") if preserve_paths
    File.join(outdir, "#{basename}.html")
  end

  # Not implementing shift() because it's not needed
  # Not implementing remove_control_chars

  def self.ensure_directory(directory)
    FileUtils.mkdir_p directory unless File.directory? directory
  end

  # This function will iterate through the list of sources and if a directory
  # is encountered it will walk the tree for any files.
  def self._flatten_sources(sources)
    result = [] of String
    sources.each do |source|
      if File.directory? source
        result += Dir.glob(File.join(source, "**", "*"))
      else
        result.push source
      end
    end
    result
  end

  # For each source file passed as argument, generate the documentation.
  def self.process(sources, preserve_paths : Bool, outdir : String, language = nil, index = false, skip = false)
    # Make a copy of sources given on the command line. `main()` needs the
    # original list when monitoring for changed files.
    sources = _flatten_sources(sources).sort

    # Proceed to generate the documentation
    unless sources.empty?
      ensure_directory(outdir)
      File.open(File.join(outdir, "crycco.css"), "w") do |css|
        css << CSS
      end

      _generated_files = [] of String

      sources.each do |source|
        dest = destination(source, preserve_paths: preserve_paths, outdir: outdir)
        ensure_directory(File.dirname(dest))
        File.open(dest, "w") do |outf|
          outf << generate_documentation(source, preserve_paths: preserve_paths,
            outdir: outdir, language: language)
          puts "crycco: #{source} -> #{dest}"
        end
      end

      # FIXME: implement generate_index
      #
      # ```python
      # if index
      #   File.open(File.join(outdir, "index.html"), "w") do |f|
      #     f << generate_index(generated_files, outdir)
      #   end
      # end
      # ```
    end
  end

  # FIXME: implement monitor

  # FIXME: do a real main

  def self.main
    preserve_paths = true
    outdir = ARGV[-1]
    index = true
    skip = false
    sources = ARGV[0...-1]

    puts "Starting"
    process(sources, preserve_paths: preserve_paths, outdir: outdir, index: index, skip: skip)
  end
end
