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
  # it in, splitting it up iunto comment/code sections,
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
    # FIXME: implement highlight function
    # highlight(sections, language, preserve_pathsL preserve_paths, outdir: outdir)
    generate_html(file_path, sections, preserve_paths: preserve_paths, outdir: outdir)
  end

  def self.parse(code, language)
    # Given a string of source code, parse out each comment and the code
    # that follows it, and create an individual **section** for it.
    #
    # Sections take the form:
    #
    # { "docs_text": ...,
    #   "docs_html": ...,
    #   "code_text": ...,
    #   "code_html": ...,
    #   "num":       ...
    # }

    lines = code.split("\n")
    sections = [] of Hash(String, String)
    has_code = docs_text = code_text = ""

    lines.shift 1 if lines[0].starts_with?("#!")

    # FIXME: not implementing the encoding comment skipping for python

    save = ->(docs : String, code : String) {
      sections.push({
        "docs_text" => docs,
        "code_text" => code,
      }) unless docs.empty? && code.empty?
    }

    multi_line = false
    multi_string = false
    multistart = language.fetch("multistart", nil)
    multiend = language.fetch("multiend", nil)
    comment_matcher = /^\s*#{language["comment_symbol"]}\s?/
    lines.each do |line|
      process_as_code = false
      # Only go into multiline comments senction when one of the delimiters
      # is foind to be at the start of a line
      # FIXME: implement multiline logic

      if comment_matcher.match(line)
        if !has_code
          save.call(docs_text, code_text)
          has_code = docs_text = code_text = ""
        end
        docs_text +=
          docs_text += line.gsub(comment_matcher, "") + "\n"
      else
        process_as_code = true
      end

      if process_as_code
        has_code = true
        code_text += line + "\n"
      end
    end
    save.call(docs_text, code_text)
    sections
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
    raise Exception.new("Missing outdir") unless outdir

    sanitize_section_name = ->(name : String) : String {
      "-".join(name.downcase.strip.split(" "))
    }

    replace_crossref = ->(match : Regex::MatchData) : String {
      # Check if the match contains an anchor
      if match[1].contains "#"
        name, anchor = match[1].split "#"
        path = File.basename(destination(name, preserve_paths: preserve_paths, outdir: outdir))
        " [#{name}](#{path}##{anchor})"
      else
        path = File.basename(destination(match[1], preserve_paths: preserve_paths, outdir: outdir))
        " [#{match[1]}](#{path})"
      end
    }

    replace_section_name = ->(match : Regex::MatchData) : String {
      # Replace equals-sign-formatted section names with anchor links
      lvl = match[1].replace("=", "#")
      id = sanitize_section_name.call(match[2])
      name = match[2]
      %(#{lvl} <span id="#{id}" href="#{id}">#{name}</span>)
    }

    comment = comment.sub(/^([=]+)([^=]+)[=]*\s*$/, replace_section_name)
    comment = comment.sub(/(?<!`)\[\[(.+?)\]\]/, replace_crossref)
    comment
  end

  # === Highlighting the source code ===
  #
  # FIXME: won't implement, trust markdown and fenced code to do it

  # === HTML Code generation ===

  def self.generate_html(source, sections, preserve_paths = true, outdir = nil)
    # Generate the HTML file and write out the documentation. Pass
    # the completed sections into the template found in
    # `resources/pycco.html`
    #
    # Crustache will attempt to recursively render context variables,
    # so we must replace any occurences of `{{`, which is valid in some
    # languages, with a "unique enough" identifier before rendering and
    # then post-process the output to restore the `{{`s.

    raise Exception.new("Missing outdir") unless outdir

    title = File.basename(source)
    dest = destination(source, preserve_paths: preserve_paths, outdir: outdir)
    css_path = Path[File.join(outdir, "pycco.css")].relative_to(File.dirname(dest)).to_s

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
  def self.destination(filepath, preserve_paths = true, outdir = nil)
    raise Exception.new("Missing outdir") unless outdir

    dirname = File.dirname(filepath)
    basename = File.basename(filepath)
    # FIXME: not implementing weird replacement

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
  def self.process(sources, preserve_paths = true, outdir = nil, language = nil, index = false, skip = false)
    raise Exception.new("Missing outdir") unless outdir

    # Make a copy of sources given on the command line. `main()` needs the
    # original list when monitoring for changed files.
    sources = _flatten_sources(sources).sort

    # Proceed to generate the documentation
    unless sources.empty?
      ensure_directory(outdir)
      File.open(File.join(outdir, "crycco.css"), "w") do |css|
        css << CSS
      end

      generated_files = [] of String

      sources.each do |s|
        dest = destination(s, preserve_paths: preserve_paths, outdir: outdir)
        ensure_directory(File.dirname(dest))
        File.open(dest, "w") do |f|
          f << generate_documentation(s, preserve_paths: preserve_paths,
            outdir: outdir, language: language)
          puts "crycco: #{s} -> #{dest}"
        end
      end

      # FIXME: implement generate_index
      # if index
      #   File.open(File.join(outdir, "index.html"), "w") do |f|
      #     f << generate_index(generated_files, outdir)
      #   end
      # end
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

    process(sources, preserve_paths: preserve_paths, outdir: outdir, index: index, skip: skip)
  end
end


Crycco.main()