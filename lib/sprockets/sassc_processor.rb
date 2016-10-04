# frozen_string_literal: true
require 'sprockets/sass_processor'
require 'base64'

module Sprockets
  class SasscProcessor < SassProcessor
    def initialize(options = {}, &block)
      @cache_version = options[:cache_version]
      @cache_key = "#{self.class.name}:#{VERSION}:#{Autoload::SassC::VERSION}:#{@cache_version}".freeze
      @importer_class = options[:importer]
      @sass_config = options[:sass_config] || {}
      @functions = Module.new do
        include SassProcessor::Functions
        include options[:functions] if options[:functions]
        class_eval(&block) if block_given?
      end
    end

    def call(input)
      context = input[:environment].context_class.new(input)

      options = engine_options(input, context)
      engine = Autoload::SassC::Engine.new(input[:data], options)

      css = Utils.module_include(Autoload::SassC::Script::Functions, @functions) do
        engine.render
      end

      map = SourceMapUtils.decode_json_source_map(engine.source_map)["mappings"]

      engine.dependencies.each do |dependency|
        context.metadata[:dependencies] << URIUtils.build_file_digest_uri(dependency.filename)
      end

      context.metadata.merge(data: css, map: map)
    end

    private

    def engine_options(input, context)
      merge_options({
        filename: input[:filename],
        syntax: self.class.syntax,
        load_paths: input[:environment].paths,
        importer: @importer_class,
        source_map_contents: true,
        source_map_file: "#{input[:filename]}.map",
        omit_source_map_url: true,
        sprockets: {
          context: context,
          environment: input[:environment],
          dependencies: context.metadata[:dependencies]
        }
      })
    end
  end


  class ScsscProcessor < SasscProcessor
    def self.syntax
      :scss
    end
  end
end
