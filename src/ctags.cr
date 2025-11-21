require "ctags"

# # Ctags Manager
#
# This module handles symbol resolution using ctags files. It provides
# a centralized way to generate, load, and query ctags information
# for enhanced smart file references.
#
# The CtagsManager supports both automatic ctags generation for Crystal
# files using crystal-ctags, and loading existing ctags files for other
# languages using universal ctags.

module Crycco
  class CtagsManager
    @@instance : CtagsManager?
    @tag_file : Ctags::File?
    @ctags_path : String

    def initialize(@files : Array(Path), @ctags_path : String)
      load_tags
    end

    # Get singleton instance
    def self.instance(files : Array(Path), ctags_path : String) : CtagsManager
      @@instance ||= new(files, ctags_path)
    end

    # Reset singleton (useful for testing)
    def self.reset
      @@instance = nil
    end

    # Symbol Resolution
    #
    # Resolve a symbol name to its definition location. Returns a tuple
    # of (file_path, line_number) if found, or nil if not found.
    #
    # The resolution follows this priority:
    # 1. Symbols in the current file
    # 2. Unique symbols across all files
    # 3. Nil if ambiguous or not found
    def resolve_symbol(symbol_name : String, current_file : Path) : {Path, Int32}?
      # First, try to find symbol in current file
      if result = find_symbol_in_file(symbol_name, current_file)
        return result
      end

      # Then try to find unique symbol across all files
      if result = find_unique_symbol(symbol_name)
        return result
      end

      nil
    end

    # Generate ctags for all files
    #
    # This method generates ctags for the provided files using the appropriate
    # tools for each language type. For Crystal files, it uses crystal-ctags.
    # For other files, it uses universal ctags if available.
    def generate_tags : Bool
      crystal_files = @files.select { |file| file.extension == ".cr" }
      other_files = @files.reject { |file| file.extension == ".cr" }

      success = true

      # Generate ctags for Crystal files
      unless crystal_files.empty?
        success &= generate_crystal_tags(crystal_files)
      end

      # Generate ctags for other files
      unless other_files.empty?
        success &= generate_universal_tags(other_files)
      end

      # Reload tags after generation
      load_tags if success

      success
    end

    # Find symbol in specific file
    private def find_symbol_in_file(symbol_name : String, file_path : Path) : {Path, Int32}?
      return nil unless @tag_file

      entries = find_entries(symbol_name)
      return nil if entries.empty?

      # Look for entries in the specified file
      entries.each do |entry|
        if Path[entry.file] == file_path
          return {Path[entry.file], entry.line_number}
        end
      end

      nil
    end

    # Find unique symbol across all files
    private def find_unique_symbol(symbol_name : String) : {Path, Int32}?
      return nil unless @tag_file

      entries = find_entries(symbol_name)
      return nil if entries.empty?
      return nil if entries.size > 1 # Ambiguous

      entry = entries.first
      {Path[entry.file], entry.line_number}
    end

    # Find all entries for a symbol name
    private def find_entries(symbol_name : String) : Array(Ctags::Entry)
      return [] of Ctags::Entry unless tag_file = @tag_file

      tag_file.find_entries(symbol_name)
    end

    # Load ctags file
    private def load_tags
      return unless File.exists?(@ctags_path)

      begin
        @tag_file = Ctags::File.new(@ctags_path)
      rescue ex
        STDERR.puts "Warning: Failed to load ctags file: #{ex.message}"
        @tag_file = nil
      end
    end

    # Generate ctags for Crystal files using crystal-ctags
    private def generate_crystal_tags(crystal_files : Array(Path)) : Bool
      # Build command with files as arguments (crystal-ctags is basic and doesn't support -L)
      file_args = crystal_files.map(&.to_s).join(" ")
      cmd = "crystal-ctags #{file_args} > #{@ctags_path} 2>&1"
      result = Process.run(
        cmd,
        shell: true,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe
      )

      unless result.success?
        STDERR.puts "Warning: crystal-ctags failed"
        return false
      end

      true
    rescue ex
      STDERR.puts "Warning: Failed to generate Crystal ctags: #{ex.message}"
      false
    end

    # Generate ctags for other files using universal ctags
    private def generate_universal_tags(other_files : Array(Path)) : Bool
      cmd = "ctags -f #{@ctags_path} #{other_files.join(" ")}"
      result = Process.run(
        cmd,
        shell: true,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe
      )

      unless result.success?
        STDERR.puts "Warning: universal ctags failed"
        return false
      end

      true
    rescue ex
      STDERR.puts "Warning: Failed to generate universal ctags: #{ex.message}"
      false
    end
  end
end
