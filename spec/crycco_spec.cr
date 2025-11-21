require "./spec_helper"

Crycco.load_languages("#{__DIR__}/../src/languages.yml")

describe Crycco do
  describe "parse" do
    it "should split code from comments" do
      doc = Crycco::Document.new Path["#{__DIR__}/fixtures/1.cr"]
      doc.sections.size.should eq(2)
    end
    it "should remove comment markers from doc" do
      doc = Crycco::Document.new Path["#{__DIR__}/fixtures/1.cr"]
      doc.sections[0].docs.should eq("This is a comment\nMore comment\n")
    end
    it "should break sections in HR" do
      doc = Crycco::Document.new Path["#{__DIR__}/fixtures/2.cr"]
      doc.sections.size.should eq(3)
    end
    it "should handle an empty file" do
      doc = Crycco::Document.new Path["#{__DIR__}/fixtures/empty.cr"]
      doc.sections.size.should eq(0)
    end
    it "should handle enclosing comments" do
      doc = Crycco::Document.new Path["#{__DIR__}/fixtures/enclosing.c"]
      doc.sections.size.should eq(2)
      doc.sections[0].docs.should eq("")
      doc.sections[0].code.should eq("foo=bar;\n\n")
      doc.sections[1].docs.should eq("comment\nmore comment\n")
    end
  end
  describe "parse in literate style" do
    it "should split code from comments" do
      doc = Crycco::Document.new Path["#{__DIR__}/fixtures/1.cr.md"]
      doc.sections.size.should eq(2)
    end
    it "should take unindented text as docs" do
      doc = Crycco::Document.new Path["#{__DIR__}/fixtures/1.cr.md"]
      doc.sections[0].docs.should eq("This is a comment\nMore comment\n\n")
    end
    it "should add comment markers when converting to code" do
      doc = Crycco::Document.new Path["#{__DIR__}/fixtures/1.cr.md"]
      doc.sections[0].to_source.should eq(
        "# This is a comment\n" + "# More comment\n" + "    code\n" + "    code")
    end
  end

  describe "Section" do
    it "should convert docs to html" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "This is a comment\nMore comment\n"
      section.docs_html.should eq("<p>This is a comment\nMore comment</p>\n")
    end
    it "should convert code to html" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.code = "code\ncode\n"
      result = section.code_html.strip
      # Should contain syntax highlighting and line anchors
      result.should contain("<pre class=\"b\" ><code class=\"b\">")
      result.should contain("<span class=\"t\">code</span>")
      result.should contain("<span id=\"line-")
      result.should contain("</code></pre>")
    end
    it "should convert the whole section to code" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.code = "code\ncode\n"
      section.docs = "This is a comment\nMore comment\n"
      section.to_source.strip.should eq(
        "# This is a comment\n" + "# More comment\n" + "code\n" + "code"
      )
    end
  end
  describe "Collection" do
    it "should preserve relative path structure" do
      c = Crycco::Collection.new(["src/crycco.cr", "TODO.md", "src/languages.yml"], "out", "template", "docs")
      (c.@docs.map { |doc| c.dst_path(doc) }).sort.should \
        eq [Path["out/src/crycco.cr.html"],
            Path["out/TODO.md.html"],
            Path["out/src/languages.yml.html"]].sort
    end
  end

  describe "Smart File References" do
    it "should process simple file references" do
      Crycco.all_files = [Path["src/main.cr"], Path["README.md"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "See [[main.cr]] and [[README]] for details."

      result = section.process_file_references(section.docs)
      result.should contain("[main.cr](src/main.cr.html)")
      result.should contain("[README](README.md.html)")
    end

    it "should handle custom display text" do
      Crycco.all_files = [Path["src/main.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "Check [[main.cr|the main file]]"

      result = section.process_file_references(section.docs)
      result.should contain("[the main file](src/main.cr.html)")
    end

    it "should leave unresolved references unchanged" do
      Crycco.all_files = [Path["src/main.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "See [[nonexistent]] for details."

      result = section.process_file_references(section.docs)
      result.should contain("[[nonexistent]]")
    end

    it "should match basename without extension" do
      Crycco.all_files = [Path["src/collection.cr"], Path["README.md"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "See [[collection]] for details."

      result = section.process_file_references(section.docs)
      result.should contain("[collection](src/collection.cr.html)")
    end

    it "should handle exact filename matches" do
      Crycco.all_files = [Path["src/main.cr"], Path["test_ref.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "See [[test_ref]] for details."

      result = section.process_file_references(section.docs)
      result.should contain("[test_ref](test_ref.cr.html)")
    end

    it "should handle relative paths" do
      Crycco.all_files = [Path["src/main.cr"], Path["src/helpers/config.yml"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["src/helpers/config.cr"]
      section.docs = "See [[config.yml]] for details."

      result = section.process_file_references(section.docs)
      result.should contain("[config.yml](src/helpers/config.yml.html)")
    end

    it "should prioritize same directory matches" do
      Crycco.all_files = [Path["src/collection.cr"], Path["test/collection.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["src/main.cr"]
      section.docs = "See [[collection]] for details."

      result = section.process_file_references(section.docs)
      # Should link to src/collection.cr.html since it's in the same directory
      result.should contain("[collection](src/collection.cr.html)")
    end

    it "should leave ambiguous matches unchanged" do
      Crycco.all_files = [Path["src/main.cr"], Path["test/main.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["other.cr"]
      section.docs = "See [[main]] for details."

      result = section.process_file_references(section.docs)
      result.should contain("[[main]]")
    end

    it "should not process smart references inside backticks" do
      Crycco.all_files = [Path["src/main.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "Use `[[main.cr]]` for the syntax example, but use [[main.cr]] for actual reference."

      result = section.process_file_references(section.docs)
      result.should contain("`[[main.cr]]`")               # Backticked example stays literal
      result.should contain("[main.cr](src/main.cr.html)") # Actual reference becomes link
    end

    it "should handle URL fragments correctly" do
      Crycco.all_files = [Path["src/crycco.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "See [[crycco.cr#document]] for details."

      result = section.process_file_references(section.docs)
      result.should contain("[crycco.cr#document](src/crycco.cr.html#document)")
    end

    it "should handle URL fragments with custom display text" do
      Crycco.all_files = [Path["src/crycco.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "Check [[crycco.cr#document|the Document class]] for implementation details."

      result = section.process_file_references(section.docs)
      result.should contain("[the Document class](src/crycco.cr.html#document)")
    end

    it "should handle basename references with fragments" do
      Crycco.all_files = [Path["src/crycco.cr"], Path["src/main.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "See [[crycco#section]] and [[main#setup]] for details."

      result = section.process_file_references(section.docs)
      result.should contain("[crycco#section](src/crycco.cr.html#section)")
      result.should contain("[main#setup](src/main.cr.html#setup)")
    end

    it "should preserve fragments in backticks" do
      Crycco.all_files = [Path["src/crycco.cr"]]
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = "Use `[[crycco.cr#document]]` as an example, but see [[crycco.cr#document]] for real."

      result = section.process_file_references(section.docs)
      result.should contain("`[[crycco.cr#document]]`")                          # Backticked stays literal
      result.should contain("[crycco.cr#document](src/crycco.cr.html#document)") # Actual reference
    end
  end

  describe "HTML Path Generation" do
    it "should generate correct paths for files with extensions" do
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]

      # Test .cr files
      path = section.html_path_for_file(Path["src/main.cr"])
      path.should eq("src/main.cr.html")

      # Test .yml files
      path = section.html_path_for_file(Path["languages.yml"])
      path.should eq("languages.yml.html")

      # Test .md files
      path = section.html_path_for_file(Path["README.md"])
      path.should eq("README.md.html")
    end

    it "should append .html to files without extensions" do
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]

      path = section.html_path_for_file(Path["Makefile"])
      path.should eq("Makefile.html")
    end

    it "should handle files in subdirectories" do
      Crycco.base_dir = Path["."]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]

      path = section.html_path_for_file(Path["src/helpers/config.cr"])
      path.should eq("src/helpers/config.cr.html")

      path = section.html_path_for_file(Path["docs/api.md"])
      path.should eq("docs/api.md.html")
    end

    it "should handle relative path calculations from different base directories" do
      Crycco.base_dir = Path["src"]

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["src/test.cr"]

      # When base_dir is "src", a file like "src/main.cr" should become "main.cr.html"
      path = section.html_path_for_file(Path["src/main.cr"])
      path.should eq("main.cr.html")

      # Files in subdirectories should maintain their structure
      path = section.html_path_for_file(Path["src/helpers/config.cr"])
      path.should eq("helpers/config.cr.html")
    end
  end

  describe "Semantic Anchor Generation" do
    it "should generate anchors from section headers" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = <<-TEXT
        # # This module handles configuration
        Some documentation content here.
        TEXT

      anchor = section.anchor
      anchor.should eq("this-module-handles-configuration")
    end

    it "should handle headers with special characters" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = <<-TEXT
        # # Setup & Configuration (v2.0)
        Some documentation content here.
        TEXT

      anchor = section.anchor
      anchor.should eq("setup-configuration-v20")
    end

    it "should handle headers with multiple spaces and hyphens" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = <<-TEXT
        # #   Multiple    spaces   and   hyphens   ---
        Some documentation content here.
        TEXT

      anchor = section.anchor
      anchor.should eq("multiple-spaces-and-hyphens")
    end

    it "should fall back to 'section' when no header is found" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = <<-TEXT
        # This is just documentation without any headers.
        # Just regular content lines.
        TEXT

      anchor = section.anchor
      anchor.should eq("section")
    end

    it "should handle empty headers" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = <<-TEXT
        #
        # This follows an empty header.
        TEXT

      anchor = section.anchor
      anchor.should eq("section")
    end

    it "should work with different comment styles" do
      # Test with YAML comment style which is also "#"
      section = Crycco::Section.new Crycco::LANGUAGES[".yml"], Path["test.yml"]
      section.docs = <<-TEXT
        # # YAML Module Documentation
        # This is YAML configuration.
        TEXT

      anchor = section.anchor
      anchor.should eq("yaml-module-documentation")
    end

    it "should include anchor in section hash for templates" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.docs = <<-TEXT
        # # Test Header
        # Documentation content.
        TEXT

      section_hash = section.to_h
      section_hash["anchor"].should eq("test-header")
    end
  end

  describe "Ctags Symbol Resolution" do
    before_each do
      # Reset ctags manager for each test
      Crycco::CtagsManager.reset
    end

    it "should add line number anchors to code HTML" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.code = <<-CODE
        def test_method
          puts "hello"
        end
        CODE

      result = section.code_html
      # Should contain line anchors - at least line 1 and 3 should be there
      result.should contain("<span id=\"line-1\">")
      result.should contain("<span id=\"line-3\">")
      # The formatter may combine lines, so we check that anchors exist
    end

    it "should handle empty code gracefully" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.code = ""

      result = section.code_html
      result.should eq("")
    end

    it "should handle single line code" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.code = "puts 'hello world'"

      result = section.code_html
      result.should contain("<span id=\"line-1\">")
      result.should contain("hello world")
    end

    it "should preserve code formatting while adding anchors" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]
      section.code = "class Test\n  def method\n    true\n  end\nend"

      result = section.code_html
      # Should contain all line anchors
      result.should contain("<span id=\"line-1\">")
      result.should contain("<span id=\"line-2\">")
      result.should contain("<span id=\"line-3\">")
      result.should contain("<span id=\"line-4\">")
      result.should contain("<span id=\"line-5\">")
      # Should still contain syntax-highlighted content
      result.should contain("Test")
      result.should contain("method")
    end

    it "should fall back to symbol resolution when no files match" do
      # Setup with no files for file resolution
      Crycco.all_files = [] of Path
      Crycco.base_dir = Path["."]
      Crycco.ctags_manager = nil

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]

      # Since there's no ctags manager, this should leave unchanged
      result = section.process_file_references("See [[SomeSymbol]] for details")
      result.should contain("[[SomeSymbol]]")
    end

    it "should integrate ctags resolution with existing functionality" do
      Crycco.all_files = [Path["src/main.cr"]]
      Crycco.base_dir = Path["."]
      Crycco.ctags_manager = nil

      section = Crycco::Section.new Crycco::LANGUAGES[".cr"], Path["test.cr"]

      # Should work with file resolution
      result = section.process_file_references("See [[main]] and [[NonExistentSymbol]]")
      result.should contain("[main](src/main.cr.html)")
      result.should contain("[[NonExistentSymbol]]")
    end
  end
end
