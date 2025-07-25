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
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"]
      section.docs = "This is a comment\nMore comment\n"
      section.docs_html.should eq("<p>This is a comment\nMore comment</p>\n")
    end
    it "should convert code to html" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"]
      section.code = "code\ncode\n"
      section.code_html.strip.should eq("<pre class=\"b\" ><code class=\"b\"><span class=\"t\">code</span><span class=\"t\">\n" +
                                        "</span><span class=\"t\">code</span></code></pre>")
    end
    it "should convert the whole section to code" do
      section = Crycco::Section.new Crycco::LANGUAGES[".cr"]
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
end
