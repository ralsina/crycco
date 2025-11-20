# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building
- `shards build` - Build the crycco binary (development mode, no --release)
- The binary is created at `bin/crycco`

### Testing
- `crystal spec` - Run all tests
- Tests are located in the `spec/` directory

### Linting
- `ameba` - Run the linter to check for style issues
- `ameba --fix` - Automatically fix linting issues when possible
- Linting configuration is in `.ameba.yml`

### Common Tasks
- Always build with `shards build` (not `--release`) after making changes
- Run tests before declaring a task finished
- Run linter and fix any issues before completing a task

## Project Architecture

Crycco is a literate programming documentation generator, similar to Docco. It processes source files and generates HTML documentation that displays comments alongside code.

### Core Components

**Main Entry Point (`src/main.cr`)**
- Command-line interface using docopt
- Parses arguments and creates a Collection to process files

**Core Logic (`src/crycco.cr`)**
- `Document` class: Parses individual source files using a state machine
- `Section` class: Represents chunks of documentation + code
- `Language` class: Defines how to parse different programming languages (loaded from YAML)
- Supports both comment-based and literate programming modes

**Collection Management (`src/collection.cr`)**
- `Collection` class: Groups multiple documents for processing
- Handles output path generation and directory structure preservation
- Manages theme context and inter-document linking

**Templates (`src/templates.cr`)**
- Uses Crinja template engine
- Templates are baked into the binary
- Supports multiple output formats: HTML docs, source code, markdown, literate markdown

### Language Support

Languages are defined in `languages.yml` with:
- Comment symbols (line comments and enclosing comments)
- Regular expressions for parsing
- Support for literate programming mode (files with `.ext.md` extension)

### Output Modes

1. **docs** (default): HTML documentation with syntax highlighting
2. **code**: Extracted source code with comments
3. **markdown**: Markdown with fenced code blocks
4. **literate**: Markdown with indented code blocks

### Dependencies

Key external libraries:
- `docopt`: CLI argument parsing
- `crinja`: Template engine
- `tartrazine`: Syntax highlighting
- `markd`: Markdown processing
- `enum_state_machine`: State machine for parsing
- `baked_file_system`: Embed templates in binary

## Code Organization

- Main source files are in `src/`
- External dependencies are in `lib/` (do not modify)
- Tests in `spec/`
- Templates in `templates/` (baked into binary)

## Special Considerations

- Files in `lib/` are external libraries and should not be modified
- The project uses docopt for CLI interfaces (per user preference)
- Uses Tartrazine for syntax highlighting instead of external highlighters
- Supports both traditional comment-based docs and literate programming
- Generated documentation is itself an example of literate programming
