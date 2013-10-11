module YARD
  module CLI
    # Condense all objects
    # @since 0.8.6
    class Condense < Yardoc
      def description; 'Condenses all objects' end

      def initialize(*args)
        super
        @serializer = Serializers::JSONSerializer.new
        @files = []

        Logger.instance.io = STDERR
      end

      # Runs the commandline utility, parsing arguments and displaying an object
      # from the {Registry}.
      #
      # @param [Array<String>] args the list of arguments.
      # @return [void]
      def run(*args)
        return unless parse_arguments(*args)
        @serializer.before_serialize
        Registry.each do |obj|
          @serializer.serialize(obj)
        end
        @serializer.after_serialize
      end

      # Parses commandline options.
      # @param [Array<String>] args each tokenized argument
      def parse_arguments(*args)
        opts = OptionParser.new
        opts.banner = "Usage: yard condense [options]"
        general_options(opts)
        parse_options(opts, args)

        parse_files(*args) unless args.empty?

        YARD.parse(self.files, [])
      end

      # Parses the file arguments into Ruby files.
      #
      # @example Parses a set of Ruby source files
      #   parse_files %w(file1 file2 file3)
      # @param [Array<String>] files the list of files to parse
      # @return [void]
      def parse_files(*files)
        files.each do |file|
          self.files << file
        end
      end
    end
  end
end
