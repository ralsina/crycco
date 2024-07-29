# # collection.cr

require "./crycco"

module Crycco
  # A Collection is a group of sources that will be processed together
  # and saved to the same output directory while preserving the directory
  # structure of the sources.
  #
  # This way the logic for path manipulation is centrallized here and
  # the Document class can be simpler.
  class Collection
    @docs : Array(Document)

    # On initialization, we create documents for each source file
    def initialize(sources : Array(String), out_dir : String, template : String, as_source : Bool)
      @docs = sources.map { |source|
        Path[source].expand.normalize
      }.sort!.map { |source|
        Document.new source, template, as_source
      }

      @out_dir = out_dir
      @template = template
      @template = "source" if as_source
      @as_source = as_source
      @base_dir = Path[common_prefix]
    end

    # Save the documents to the output directory.
    #
    # As extra context for rendering, we pass links to all
    # the documents in the collection.
    def save
      @docs.each do |doc|
        dst = dst_path doc
        puts "#{doc.path} -> #{dst}"
        links = {} of String => String
        @docs.each do |doclink|
          target = dst_path(doclink).relative_to(@out_dir).to_s
          target = "#" if doclink == doc
          links[doclink.path.relative_to(@base_dir).to_s] = target
        end
        doc.save dst, {"links" => links}
      end
    end

    # Calculate destionation paths for the documents.
    # If the `as_source` option is set, the output should be a source
    # file, so it will have the language's extension and use the source
    # template.
    #
    # If the source is literate (eg: `foo.yml.md`), the destination
    # will have the same name as the source but without the final ".md"
    #
    # When the output is a document, ".html" is appended to the destination.
    def dst_path(doc : Document) : Path
      dst = (Path[@out_dir] / Path[doc.path].relative_to(@base_dir)).to_s
      dst += ".html" unless @as_source
      if doc.@literate && File.extname(dst) == ".md"
        dst = dst[...-3]
      end
      Path[dst]
    end

    # Find the common prefix of the sources, this is used to preserve the
    # directory structure when saving the documents.
    def common_prefix : String
      sources = @docs.map &.path
      candidate = Path[sources[0]].dirname
      until sources.all? { |source| Path[source].dirname.starts_with? candidate }
        candidate = Path[candidate].dirname
      end
      candidate
    end
  end
end
