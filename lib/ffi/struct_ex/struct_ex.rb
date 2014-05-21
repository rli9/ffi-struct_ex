require 'ffi'

class Integer
  def to_bytes(size)
    bytes = [0] * size
    bytes.each_index do |i|
      bytes[i] = (self >> (i * 8)) & 0xff
    end

    bytes
  end
end

class String
  def to_dec
    case self
      when /^[+-]?\d+$/
        self.to_i
      when /^[+-]?0[xX][\da-fA-F_]+$/
        self.to_i(16)
      when /^[+-]?0[bB][_01]+$/
        self.to_i(2)
    end
  end
end

module FFI
  class StructEx < FFI::Struct
    class << self
      def bit_fields(*field_specs)
        struct_class = Class.new(StructEx) do
          layout(*field_specs)
        end

        bit_fields_class = Class.new(FFI::StructLayout::Field) do
          def initialize(name, offset, type)
            super(name, offset, FFI::Type::Struct.new(self.class.struct_class))
          end

          def get(ptr)
            #self.class.struct_class == type.struct_class
            self.class.struct_class.new(ptr.slice(self.offset, self.size))
          end

          def put(ptr, value)
            self.class.struct_class.new(ptr.slice(self.offset, self.size)).write(value)
          end

          class << self
            attr_accessor :struct_class

            def alignment
              struct_class.alignment
            end

            def size
              struct_class.size
            end
          end

          self.struct_class = struct_class
        end
      end

      attr_reader :bits_size, :field_specs, :has_bit_field

      def layout(*field_specs)
        return super if field_specs.size == 0

        field_spec_class = ::Struct.new(:name, :type, :bits_offset, :descriptors)

        @field_specs = {}

        i = bits_offset = 0

        while i < field_specs.size
          field_name, type = field_specs[i, 2]
          i += 2

          unless type.is_a?(Integer)
            type = find_field_type(type)
            bits_size = type.size * 8

            if field_specs[i].is_a?(Integer)
              bits_offset = field_specs[i] * 8
              i += 1
            end
          else
            bits_size = type
          end

          if field_specs[i].is_a?(Hash)
            descriptors = field_specs[i]
            i += 1
          else
            descriptors = {}
          end

          @field_specs[field_name] = field_spec_class.new(field_name, type, bits_offset, descriptors)
          bits_offset += bits_size
        end

        @has_bit_field = @field_specs.any? {|field_name, field_spec| field_spec.type.is_a?(Integer)}

        if @has_bit_field
          #FIXME consider 24 bits situation or larger than 32 bits
          #FIXME remove dummy field or have a better name for this field
          super(:dummy, "uint#{(bits_offset + 7) & (-1 << 3)}".to_sym)
        else
          super(*field_specs.reject {|field_spec| field_spec.is_a?(Hash)})
        end
      end
    end

    def initialize(options = {})
      if options.is_a?(FFI::Pointer)
        super(options)
      else
        super()
        write(options)
      end
    end

    def [](field_name)
      return super unless self.class.has_bit_field

      field_spec = self.class.field_specs[field_name]
      mask = ((1 << field_spec.type) - 1) << field_spec.bits_offset

      (self.read & mask) >> field_spec.bits_offset
    end

    # Set field value
    def []=(field_name, value)
      value = map_field_value(field_name, value)

      return super(field_name, value) unless self.class.has_bit_field

      field_spec = self.class.field_specs[field_name]
      mask = ((1 << field_spec.type) - 1) << field_spec.bits_offset

      self.write((self.read & (-1 - mask)) | ((value << field_spec.bits_offset) & mask))
    end

    def write(value)
      if value.is_a?(Integer)
        to_ptr.write_array_of_uint8(value.to_bytes(self.class.size))
      elsif value.is_a?(Hash)
        value.each do |field_name, v|
          self[field_name] = v
        end
      end
    end

    def read
      bytes = to_ptr.read_array_of_uint8(self.class.size)
      bytes.reverse.inject(0) {|value, n| (value << 8) | n}
    end

    def ==(other)
      if other.is_a?(Integer)
        self.read == other
      elsif other.is_a?(String)
        self.==(other.to_dec)
      elsif other.is_a?(Hash)
        other.all? {|k, v| self[k] == self.map_field_value(k, v)}
      else
        super
      end
    end

    # Return mapped field value by converting {value} to corresponding native form.
    # The priority is
    #   1. look for descriptors
    #   2. simple conversion from string to integer if integer type
    #   3. {value} itself
    #
    # @param [String, Symbol] field_name name of the field
    # @param [String, Integer, Object] value value in descriptive form or native form
    # @return [Object] value in native form
    def map_field_value(field_name, value)
      field_spec = self.class.field_specs[field_name]

      descriptor_key = value.kind_of?(String) ? value.downcase : value
      return field_spec.descriptors[descriptor_key] if field_spec.descriptors.has_key?(descriptor_key)

      type = field_spec.type
      return value.to_dec if (type.is_a?(Integer) || FFI::StructLayoutBuilder::NUMBER_TYPES.include?(type)) && value.is_a?(String)

      value
    end
  end
end
