require 'rdoc'

require 'rdoc/parser'

# Simple must come first
require 'rdoc/parser/simple'
require 'rdoc/parser/ruby'
require 'rdoc/parser/c'
require 'rdoc/parser/perl'

require 'rdoc/stats'
require 'rdoc/options'

require 'find'
require 'fileutils'
require 'time'

##
# Encapsulate the production of rdoc documentation. Basically you can use this
# as you would invoke rdoc from the command line:
#
#   rdoc = RDoc::RDoc.new
#   rdoc.document(args)
#
# Where +args+ is an array of strings, each corresponding to an argument you'd
# give rdoc on the command line. See rdoc/rdoc.rb for details.

class RDoc::RDoc

  ##
  # File pattern to exclude

  attr_accessor :exclude

  ##
  # Generator instance used for creating output

  attr_accessor :generator

  ##
  # RDoc options

  attr_accessor :options

  ##
  # Accessor for statistics.  Available after each call to parse_files

  attr_reader :stats

  ##
  # This is the list of supported output generators

  GENERATORS = {}

  ##
  # Add +klass+ that can generate output after parsing

  def self.add_generator(klass)
    name = klass.name.sub(/^RDoc::Generator::/, '').downcase
    GENERATORS[name] = klass
  end

  ##
  # Active RDoc::RDoc instance

  def self.current
    @current
  end

  ##
  # Sets the active RDoc::RDoc instance

  def self.current=(rdoc)
    @current = rdoc
  end

  def initialize
    @current      = nil
    @exclude      = nil
    @generator    = nil
    @last_created = nil
    @old_siginfo  = nil
    @options      = nil
    @stats        = nil
  end

  ##
  # Report an error message and exit

  def error(msg)
    raise RDoc::Error, msg
  end

  ##
  # Gathers a set of parseable files from the files and directories listed in
  # +files+.

  def gather_files files
    files = ["."] if files.empty?

    file_list = normalized_file_list files, true, @exclude

    file_list = file_list.uniq

    file_list = remove_unparseable file_list
  end

  ##
  # Turns RDoc from stdin into HTML

  def handle_pipe
    @html = RDoc::Markup::ToHtml.new

    out = @html.convert $stdin.read

    $stdout.write out
  end

  ##
  # Installs a siginfo handler that prints the current filename.

  def install_siginfo_handler
    return unless Signal.list.include? 'INFO'

    @old_siginfo = trap 'INFO' do
      puts @current if @current
    end
  end

  ##
  # Create an output dir if it doesn't exist. If it does exist, but doesn't
  # contain the flag file <tt>created.rid</tt> then we refuse to use it, as
  # we may clobber some manually generated documentation

  def setup_output_dir(op_dir, force)
    flag_file = output_flag_file op_dir

    if File.exist? op_dir then
      unless File.directory? op_dir then
        error "'#{op_dir}' exists, and is not a directory"
      end
      begin
        created = File.read(flag_file)
      rescue SystemCallError
        error "\nDirectory #{op_dir} already exists, but it looks like it\n" +
          "isn't an RDoc directory. Because RDoc doesn't want to risk\n" +
          "destroying any of your existing files, you'll need to\n" +
          "specify a different output directory name (using the\n" +
          "--op <dir> option).\n\n"
      else
        last = (Time.parse(created) unless force rescue nil)
      end
    else
      FileUtils.mkdir_p(op_dir)
    end

    last
  end

  ##
  # Update the flag file in an output directory.

  def update_output_dir(op_dir, time)
    File.open(output_flag_file(op_dir), "w") { |f| f.puts time.rfc2822 }
  end

  ##
  # Return the path name of the flag file in an output directory.

  def output_flag_file(op_dir)
    File.join op_dir, "created.rid"
  end

  ##
  # The .document file contains a list of file and directory name patterns,
  # representing candidates for documentation. It may also contain comments
  # (starting with '#')

  def parse_dot_doc_file in_dir, filename
    # read and strip comments
    patterns = File.read(filename).gsub(/#.*/, '')

    result = []

    patterns.split.each do |patt|
      candidates = Dir.glob(File.join(in_dir, patt))
      result.concat normalized_file_list(candidates)
    end

    result
  end

  ##
  # Given a list of files and directories, create a list of all the Ruby
  # files they contain.
  #
  # If +force_doc+ is true we always add the given files, if false, only
  # add files that we guarantee we can parse.  It is true when looking at
  # files given on the command line, false when recursing through
  # subdirectories.
  #
  # The effect of this is that if you want a file with a non-standard
  # extension parsed, you must name it explicitly.

  def normalized_file_list(relative_files, force_doc = false,
                           exclude_pattern = nil)
    file_list = []

    relative_files.each do |rel_file_name|
      next if exclude_pattern && exclude_pattern =~ rel_file_name
      stat = File.stat rel_file_name rescue next

      case type = stat.ftype
      when "file"
        next if @last_created and stat.mtime < @last_created

        if force_doc or RDoc::Parser.can_parse(rel_file_name) then
          file_list << rel_file_name.sub(/^\.\//, '')
        end
      when "directory"
        next if rel_file_name == "CVS" || rel_file_name == ".svn"

        dot_doc = File.join rel_file_name, RDoc::DOT_DOC_FILENAME

        if File.file?(dot_doc) then
          file_list << parse_dot_doc_file(rel_file_name, dot_doc)
        else
          file_list << list_files_in_directory(rel_file_name)
        end
      else
        raise RDoc::Error, "I can't deal with a #{type} #{rel_file_name}"
      end
    end

    file_list.flatten
  end

  ##
  # Return a list of the files to be processed in a directory. We know that
  # this directory doesn't have a .document file, so we're looking for real
  # files. However we may well contain subdirectories which must be tested
  # for .document files.

  def list_files_in_directory dir
    files = Dir.glob File.join(dir, "*")

    normalized_file_list files, false, @options.exclude
  end

  ##
  # Parses +filename+ and returns an RDoc::TopLevel

  def parse_file filename
    @stats.add_file filename
    content = read_file_contents filename

    return unless content

    top_level = RDoc::TopLevel.new filename

    parser = RDoc::Parser.for top_level, filename, content, @options, @stats

    return unless parser

    parser.scan
  rescue => e
    $stderr.puts <<-EOF
Before reporting this, could you check that the file you're documenting
compiles cleanly--RDoc is not a full Ruby parser, and gets confused easily if
fed invalid programs.

The internal error was:

\t(#{e.class}) #{e.message}

    EOF

    $stderr.puts e.backtrace.join("\n\t") if $RDOC_DEBUG

    raise e
    nil
  end

  ##
  # Parse each file on the command line, recursively entering directories.

  def parse_files files
    file_list = gather_files files

    return [] if file_list.empty?

    file_info = []

    @stats = RDoc::Stats.new file_list.size, @options.verbosity
    @stats.begin_adding

    file_info = file_list.map do |filename|
      @current = filename
      parse_file filename
    end.compact

    @stats.done_adding

    file_info
  end

  ##
  # Removes file extensions known to be unparseable from +files+

  def remove_unparseable files
    files.reject do |file|
      file =~ /\.(?:class|eps|erb|scpt\.txt|ttf|yml)$/i
    end
  end

  ##
  # Format up one or more files according to the given arguments.
  #
  # For simplicity, +argv+ is an array of strings, equivalent to the strings
  # that would be passed on the command line. (This isn't a coincidence, as
  # we _do_ pass in ARGV when running interactively). For a list of options,
  # see rdoc/rdoc.rb. By default, output will be stored in a directory
  # called +doc+ below the current directory, so make sure you're somewhere
  # writable before invoking.
  #
  # Throws: RDoc::Error on error

  def document(argv)
    RDoc::TopLevel.reset
    RDoc::Parser::C.reset
    RDoc::AnyMethod.reset

    @options = RDoc::Options.new
    @options.parse argv

    if @options.pipe then
      handle_pipe
      exit
    end

    @exclude = @options.exclude

    @last_created = setup_output_dir @options.op_dir, @options.force_update

    start_time = Time.now

    file_info = parse_files @options.files

    @options.title = "RDoc Documentation"

    if file_info.empty?
      $stderr.puts "\nNo newer files." unless @options.quiet
    else
      gen_klass = @options.generator

      unless @options.quiet then
        $stderr.puts "\nGenerating #{gen_klass.name.sub(/^.*::/, '')}..."
      end

      @generator = gen_klass.for @options

      pwd = Dir.pwd

      Dir.chdir @options.op_dir do
        begin
          self.class.current = self

          @generator.generate file_info
          update_output_dir ".", start_time
        ensure
          self.class.current = nil
        end
      end
    end

    unless @options.quiet or not @stats then
      puts
      @stats.print
    end
  end

  def read_file_contents(filename)
    content = if RUBY_VERSION >= '1.9' then
                File.open(filename, "r:ascii-8bit") { |f| f.read }
              else
                File.read filename
              end

    if defined? Encoding then
      if /coding:\s*([\w-]+)/i =~ content[/\A(?:.*\n){0,2}/]
        if enc = ::Encoding.find($1)
          content.force_encoding(enc)
        end
      end
    end

    content
  rescue Errno::EISDIR, Errno::ENOENT
    nil
  end

  ##
  # Removes a siginfo handler and replaces the previous

  def remove_siginfo_handler
    return unless Signal.list.key? 'INFO'

    handler = @old_siginfo || 'DEFAULT'

    trap 'INFO', handler
  end

end

begin
  require 'rubygems'

  if Gem.respond_to? :find_files then
    rdoc_extensions = Gem.find_files 'rdoc/discover'

    rdoc_extensions.each do |extension|
      begin
        load extension
      rescue => e
        warn "error loading #{extension.inspect}: #{e.message} (#{e.class})"
      end
    end
  end
rescue LoadError
end

# require built-in generators after discovery in case they've been replaced
require 'rdoc/generator/darkfish'
require 'rdoc/generator/ri'

