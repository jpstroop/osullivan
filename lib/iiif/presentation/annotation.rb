require File.join(File.dirname(__FILE__), 'abstract_resource')

module IIIF
  module Presentation
    class Annotation < AbstractResource

      TYPE = 'oa:Annotation'

      def required_keys
        super + %w{ motivation on }
      end

      def string_only_keys
        super + %w{ on }
      end

      def abstract_resource_only_keys
        super + [ { key: 'resource', type: IIIF::Presentation::Resource } ]
      end

      def initialize(hsh={})
        hsh['@type'] = TYPE unless hsh.has_key? '@type'
        hsh['motivation'] = 'sc:painting' unless hsh.has_key? 'motivation'
        super(hsh)
      end

    end
  end
end
