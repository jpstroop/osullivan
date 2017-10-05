require File.join(File.dirname(__FILE__), 'hash_behaviours')
require 'active_support/core_ext/class/subclasses'
require 'active_support/ordered_hash'
require 'active_support/inflector'
require 'json'

module IIIF
  class Service
    include IIIF::HashBehaviours

    # Anything goes! SHOULD have @id and profile, MAY have label
    # Consider subclassing this for typical services...
    def required_keys; %w{ }; end
    def any_type_keys; %w{ }; end
    def string_only_keys; %w{ }; end
    def array_only_keys; %w{ }; end
    def abstract_resource_only_keys; %w{ }; end
    def hash_only_keys; %w{ }; end
    def int_only_keys; %w{ }; end

    def initialize(hsh={})
      @data = IIIF::OrderedHash[hsh]
      self.define_methods_for_any_type_keys
      self.define_methods_for_array_only_keys
      self.define_methods_for_string_only_keys
      self.define_methods_for_int_only_keys
      self.define_methods_for_abstract_resource_only_keys
      self.snakeize_keys
    end

    # Static methods / alternative constructors
    class << self
      # Parse from a file path, string, or existing hash
      def parse(s)
        ordered_hash = nil
        if s.kind_of?(String) && File.exists?(s)
          ordered_hash = IIIF::OrderedHash[JSON.parse(IO.read(s))]
        elsif s.kind_of?(String) && !File.exists?(s)
          ordered_hash = IIIF::OrderedHash[JSON.parse(s)]
        elsif s.kind_of?(Hash)
          ordered_hash = IIIF::OrderedHash[s]
        else
          m = '#parse takes a path to a file, a JSON String, or a Hash, '
          m += "argument was a #{s.class}."
          if s.kind_of?(String)
            m+= "If you were trying to point to a file, does it exist?"
          end
          raise ArgumentError, m
        end
        return IIIF::Service.from_ordered_hash(ordered_hash)
      end
    end

    def validate
      # TODO:
      # * check for required keys
      # * type check Array-only values
      # * type check String-only values
      # * type check Integer-only values
      # * type check AbstractResource-only values
      self.required_keys.each do |k|
        unless self.has_key?(k)
          m = "A(n) #{k} is required for each #{self.class}"
          raise IIIF::Presentation::MissingRequiredKeyError, m
        end
      end
      # Viewing Direction values
      if self.has_key?('viewing_direction')
        unless self.legal_viewing_direction_values.include?(self['viewing_direction'])
          m = "viewingDirection must be one of #{legal_viewing_direction_values}"
          raise IIIF::Presentation::IllegalValueError, m
        end
      end
      # Viewing Hint values
      if self.has_key?('viewing_hint')
        unless self.legal_viewing_hint_values.include?(self['viewing_hint'])
          m = "viewingHint for #{self.class} must be one of #{self.legal_viewing_hint_values}."
          raise IIIF::Presentation::IllegalValueError, m
        end
      end
      # Metadata is all hashes
      if self.has_key?('metadata')
        unless self['metadata'].all? { |entry| entry.kind_of?(Hash) }
          m = 'All entries in the metadata list must be a type of Hash'
          raise IIIF::Presentation::IllegalValueError, m
        end
      end
    end

    # Options
    #  * pretty: (true|false). Should the JSON be pretty-printed? (default: false)
    #  * All options available in #to_ordered_hash
    def to_json(opts={})
      hsh = self.to_ordered_hash(opts)
      if opts.fetch(:pretty, false)
        JSON.pretty_generate(hsh)
      else
        hsh.to_json
      end
    end

    # Options:
    #  * force: (true|false). Skips validations.
    #  * sort_json_ld_keys: (true|false). Brings all properties starting with
    #      '@'. Default: true. to the top of the document and sorts them.
    def to_ordered_hash(opts={})
      force = opts.fetch(:force, false)
      sort_json_ld_keys = opts.fetch(:sort_json_ld_keys, true)

      unless force
        self.validate
      end

      export_hash = IIIF::OrderedHash.new

      if sort_json_ld_keys
        self.keys.select { |k| k.start_with?('@') }.sort!.each do |k|
          export_hash[k] = self.data[k]
        end
      end

      sub_opts = {
        include_context: false,
        sort_json_ld_keys: sort_json_ld_keys,
        force: force
      }
      self.keys.each do |k|
        unless sort_json_ld_keys && k.start_with?('@')
          if self.data[k].respond_to?(:to_ordered_hash) #.respond_to?(:to_ordered_hash)
            export_hash[k] = self.data[k].to_ordered_hash(sub_opts)

          elsif self.data[k].kind_of?(Hash)
            export_hash[k] = IIIF::OrderedHash.new
            self.data[k].each do |sub_k, v|

              if v.respond_to?(:to_ordered_hash)
                export_hash[k][sub_k] = v.to_ordered_hash(sub_opts)

              elsif v.kind_of?(Array)
                export_hash[k][sub_k] = []
                v.each do |member|
                  if member.respond_to?(:to_ordered_hash)
                    export_hash[k][sub_k] << member.to_ordered_hash(sub_opts)
                  else
                    export_hash[k][sub_k] << member
                  end
                end
              else
                export_hash[k][sub_k] = v
              end
            end

          elsif self.data[k].kind_of?(Array)
            export_hash[k] = []

            self.data[k].each do |member|
              if member.respond_to?(:to_ordered_hash)
                export_hash[k] << member.to_ordered_hash(sub_opts)

              elsif member.kind_of?(Hash)
                hsh = IIIF::OrderedHash.new
                export_hash[k] << hsh
                member.each do |sub_k,v|

                  if v.respond_to?(:to_ordered_hash)
                    hsh[sub_k] = v.to_ordered_hash(sub_opts)

                  elsif v.kind_of?(Array)
                    hsh[sub_k] = []

                    v.each do |sub_member|
                      if sub_member.respond_to?(:to_ordered_hash)
                        hsh[sub_k] << sub_member.to_ordered_hash(sub_opts)
                      else
                        hsh[sub_k] << sub_member
                      end
                    end
                  else
                    hsh[sub_k] = v
                  end
                end

              else
                export_hash[k] << member
                # there are no nested arrays, right?
              end
            end
          else
            export_hash[k] = self.data[k]
          end

        end
      end
      export_hash.remove_empties
      export_hash.camelize_keys
      export_hash
    end

    def self.from_ordered_hash(hsh, default_klass=IIIF::OrderedHash)
      # Create a new object (new_object)
      type = nil
      if hsh.has_key?('@type')
        type = IIIF::Service.get_descendant_class_by_jld_type(hsh['@type'])
      end
      new_object = type.nil? ? default_klass.new : type.new

      hsh.keys.each do |key|
        new_key = key.underscore == key ? key : key.underscore
        if new_key == 'service' && !hsh[key].kind_of?(Array) 
          new_object[new_key] = IIIF::Service.from_ordered_hash(hsh[key], IIIF::Service)
        elsif new_key == 'resource'
          new_object[new_key] = IIIF::Service.from_ordered_hash(hsh[key], IIIF::Presentation::Resource)
        elsif hsh[key].kind_of?(Hash)
          new_object[new_key] = IIIF::Service.from_ordered_hash(hsh[key])
        elsif hsh[key].kind_of?(Array)
          new_object[new_key] = []
          hsh[key].each do |member|
            if new_key == 'service'
              new_object[new_key] << IIIF::Service.from_ordered_hash(member, IIIF::Service)
            elsif member.kind_of?(Hash)
              new_object[new_key] << IIIF::Service.from_ordered_hash(member)
            else
              new_object[new_key] << member
              # Again, no nested arrays, right?
            end
          end
        else
          new_object[new_key] = hsh[key]
        end
      end
      new_object
    end

    protected

    def self.get_descendant_class_by_jld_type(type)
      IIIF::Service.all_service_subclasses.find do |klass|
        klass.const_defined?(:TYPE) && klass.const_get(:TYPE) == type
      end
    end

    # All known subclasses of service.
    def self.all_service_subclasses
      @all_service_subclasses ||= IIIF::Service.descendants.reject(&:singleton_class?)
    end

    def data=(hsh)
      @data = hsh
    end

    def data
      @data
    end

    def define_methods_for_any_type_keys
      any_type_keys.each do |key|
        # Setters
        define_singleton_method("#{key}=") do |arg|
          self.send('[]=', key, arg)
        end
        if key.camelize(:lower) != key
          define_singleton_method("#{key.camelize(:lower)}=") do |arg|
            self.send('[]=', key, arg)
          end
        end
        # Getters
        define_singleton_method(key) do
          self.send('[]', key)
        end
        if key.camelize(:lower) != key
          define_singleton_method(key.camelize(:lower)) do
            self.send('[]', key)
          end
        end
      end
    end

    def define_methods_for_array_only_keys
      array_only_keys.each do |key|
        # Setters
        define_singleton_method("#{key}=") do |arg|
          unless arg.kind_of?(Array)
            m = "#{key} must be an Array."
            raise IIIF::Presentation::IllegalValueError, m
          end
          self.send('[]=', key, arg)
        end
        if key.camelize(:lower) != key
          define_singleton_method("#{key.camelize(:lower)}=") do |arg|
            unless arg.kind_of?(Array)
              m = "#{key} must be an Array."
              raise IIIF::Presentation::IllegalValueError, m
            end
            self.send('[]=', key, arg)
          end
        end
        # Getters
        define_singleton_method(key) do
          self[key] ||= []
          self[key]
        end
        if key.camelize(:lower) != key
          define_singleton_method(key.camelize(:lower)) do
            self.send('[]', key)
          end
        end
      end
    end

    def define_methods_for_abstract_resource_only_keys
      # keys in this case is an array of hashes with { key: 'k', type: Class }
      abstract_resource_only_keys.each do |hsh|
        key = hsh[:key]
        type = hsh[:type]
        # Setters
        define_singleton_method("#{key}=") do |arg|
          unless arg.kind_of?(type)
            m = "#{key} must be an #{type}."
            raise IIIF::Presentation::IllegalValueError, m
          end
          self.send('[]=', key, arg)
        end
        if key.camelize(:lower) != key
          define_singleton_method("#{key.camelize(:lower)}=") do |arg|
            unless arg.kind_of?(type)
              m = "#{key} must be an #{type}."
              raise IIIF::Presentation::IllegalValueError, m
            end
            self.send('[]=', key, arg)
          end
        end
        # Getters
        define_singleton_method(key) do
          self[key] ||= []
          self[key]
        end
        if key.camelize(:lower) != key
          define_singleton_method(key.camelize(:lower)) do
            self.send('[]', key)
          end
        end
      end
    end


    def define_methods_for_string_only_keys
      string_only_keys.each do |key|
        # Setter
        define_singleton_method("#{key}=") do |arg|
          unless arg.kind_of?(String)
            m = "#{key} must be an String."
            raise IIIF::Presentation::IllegalValueError, m
          end
          self.send('[]=', key, arg)
        end
        if key.camelize(:lower) != key
          define_singleton_method("#{key.camelize(:lower)}=") do |arg|
            unless arg.kind_of?(String)
              m = "#{key} must be an String."
              raise IIIF::Presentation::IllegalValueError, m
            end
            self.send('[]=', key, arg)
          end
        end
        # Getter
        define_singleton_method(key) do
          self[key] ||= []
          self[key]
        end
        if key.camelize(:lower) != key
          define_singleton_method(key.camelize(:lower)) do
            self.send('[]', key)
          end
        end
      end
    end

    def define_methods_for_int_only_keys
      int_only_keys.each do |key|
        # Setter
        define_singleton_method("#{key}=") do |arg|
          unless arg.kind_of?(Integer) && arg > 0
            m = "#{key} must be a positive Integer."
            raise IIIF::Presentation::IllegalValueError, m
          end
          self.send('[]=', key, arg)
        end
        if key.camelize(:lower) != key
          define_singleton_method("#{key.camelize(:lower)}=") do |arg|
            unless arg.kind_of?(Integer) && arg > 0
              m = "#{key} must be a positive Integer."
              raise IIIF::Presentation::IllegalValueError, m
            end
            self.send('[]=', key, arg)
          end
        end
        # Getter
        define_singleton_method(key) do
          self[key] ||= []
          self[key]
        end
        if key.camelize(:lower) != key
          define_singleton_method(key.camelize(:lower)) do
            self.send('[]', key)
          end
        end
      end
    end

  end
end
