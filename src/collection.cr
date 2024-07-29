# A Collection is a group of sources that will be processed together
# and saved to the same output directory while preserving the directory
# structure of the sources.

module Crycco
  class Collection
    @sources : Array(Path)

    def initialize(sources : Array(String), out_dir : String, template : String, as_source : Bool)
      @sources = sources.map { |s| Path[s].expand.normalize }
      pp! @sources
      @out_dir = out_dir
      @template = template
      @as_source = as_source
      @base_dir = Path[common_prefix]
    end

    def process
      sources.each do |source|
        puts "#{source} -> #{dst_path source}"
      end
    end

    def dst_path(source : Path) : Path
      Path[@out_dir] / Path[source].relative_to(@base_dir)
    end

    def common_prefix : String
      candidate = Path[@sources[0]].dirname
      until @sources.all? { |source| Path[source].dirname.starts_with? candidate }
        candidate = Path[candidate].dirname
      end
      candidate
    end
  end
end
