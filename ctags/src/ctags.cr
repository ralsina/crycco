# Pure Crystal Ctags Parser
#
# A Crystal-based ctags parser that handles the extended ctags format
# with proper line number and field parsing, without requiring any C libraries.
module Ctags
  # Represents a single ctags entry
  class Entry
    property name : String
    property file : String
    property pattern : String
    property line_number : Int32
    property kind : String
    property fields : Hash(String, String)

    def initialize(@name, @file, @pattern, @line_number = 0, @kind = "", @fields = Hash(String, String).new)
    end

    def line_number : Int32
      # Try to parse line number from fields if not set
      if @line_number == 0 && @fields.has_key?("line")
        if line_match = @fields["line"].match(/(\d+)/)
          return line_match[1].to_i
        end
      end
      @line_number
    end
  end

  # Main ctags file parser
  class CtagsFile
    getter entries : Hash(String, Array(Entry))

    def initialize(@path : String)
      @entries = Hash(String, Array(Entry)).new
      parse_file
    end

    # Find all entries for a symbol name
    def find_entries(symbol_name : String) : Array(Entry)
      @entries[symbol_name]? || [] of Entry
    end

    # Find first entry for a symbol name (mimics libctags interface)
    def find_entry(symbol_name : String) : Entry?
      entries = find_entries(symbol_name)
      entries.first?
    end

    private def parse_file
      return unless ::File.exists?(@path)

      ::File.each_line(@path) do |line|
        line = line.strip

        # Skip comments and empty lines
        next if line.empty? || line.starts_with?("!")

        # Parse ctags line format:
        # name\tfile\tpattern;"\tfields...
        parts = line.split('\t')
        next if parts.size < 3

        name = parts[0]
        file = parts[1]

        # Everything from part 2 onwards is pattern and fields
        # Find the ;" that ends the pattern
        pattern_end_idx = 2
        pattern = parts[2]

        # Check if pattern contains the ;" ending
        if pattern.ends_with?("\";\"")
          pattern = pattern[0..-2] # Remove ;" from the end
          pattern_end_idx = 3 # Fields start after pattern
        end

        # Parse fields from remaining parts
        fields = Hash(String, String).new
        line_number = 0
        kind = ""

        (pattern_end_idx...parts.size).each do |i|
          field_part = parts[i]
          next if field_part.empty?

          if field_part.includes?(':')
            key, value = field_part.split(':', 2)
            fields[key] = value

            case key
            when "line"
              line_number = value.to_i
            when "kind"
              kind = value
            end
          else
            # Single letter field without value (like 'c', 'm', 'd')
            # This is usually the kind
            kind = field_part if field_part.match(/^[a-z]$/)
          end
        end

        entry = Entry.new(name, file, pattern, line_number, kind, fields)
        @entries[name] ||= [] of Entry
        @entries[name] << entry
      end
    end
  end

  # Alias for backward compatibility
  alias File = CtagsFile
end
