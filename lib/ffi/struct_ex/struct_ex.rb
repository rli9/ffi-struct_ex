require 'ffi'

class Integer
  def to_bytes(size)
    bytes = [0] * size
    bytes.each_index do |i|
      bytes[i] = (self >> (i * 8)) & 0xff
    end

    bytes
  end

  def to_signed(bits_size)
    self & (1 << bits_size - 1) != 0 ? self - (1 << bits_size) : self
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
        Class.new(FFI::StructLayout::Field) do
          class << self
            attr_accessor :struct_class

            def alignment; struct_class.alignment; end
            def size; struct_class.size; end
          end

          self.struct_class = Class.new(StructEx) do
            layout(*field_specs)
          end

          def initialize(name, offset, type)
            super(name, offset, FFI::Type::Struct.new(self.class.struct_class))
          end

          def get(ptr)
            type.struct_class.new(ptr.slice(offset, size))
          end

          def put(ptr, value)
            type.struct_class.new(ptr.slice(offset, size)).write(value)
          end
        end
      end

      def bit_field(type, bits_size, bits_offset)
        Class.new(FFI::StructLayout::Field) do
          class << self
            attr_accessor :type, :bits_size, :bits_offset, :struct_class
            #no need to implement alignment b/c we always provide offset when adding this field to struct_layout_builder
          end

          self.struct_class = Class.new(Struct) do
            layout('', type)
          end

          self.type, self.bits_size, self.bits_offset = type, bits_size, bits_offset

          def initialize(name, offset, type)
            super(name, offset, FFI::Type::Struct.new(self.class.struct_class))
          end

          def read(ptr)
            ptr.slice(offset, size).send("read_uint#{size * 8}".to_sym)
          end

          def write(ptr, value)
            ptr.slice(offset, size).send("write_uint#{size * 8}".to_sym, value)
          end

          def get(ptr)
            mask = (1 << self.class.bits_size) - 1
            value = (read(ptr) >> self.class.bits_offset) & mask

            [FFI::Type::INT8, FFI::Type::INT16, FFI::Type::INT32, FFI::Type::INT64].include?(self.class.type) ? value.to_signed(self.class.bits_size) : value
          end

          def put(ptr, value)
            mask = ((1 << self.class.bits_size) - 1) << self.class.bits_offset
            write(ptr, (read(ptr) & ~mask) | ((value << self.class.bits_offset) & mask))
          end
        end
      end

      attr_reader :field_specs

      def layout(*field_specs)
        return super if field_specs.size == 0

        field_spec_class = ::Struct.new(:name, :type, :bits_offset, :descriptors)

        @field_specs = {}

        @offset = 0

        i = 0
        while i < field_specs.size
          name, type = field_specs[i, 2]
          i += 2

          unless type.is_a?(Integer) || type.is_a?(String)
            if field_specs[i].is_a?(Integer)
              offset = field_specs[i]
              i += 1
            else
              offset = nil
            end
          end

          if field_specs[i].is_a?(Hash)
            descriptors = field_specs[i]
            i += 1
          else
            descriptors = {}
          end

          ffi_type, offset = add(name, type, offset, descriptors)

          if type.is_a?(Integer) || type.is_a?(String)
            if field_specs[i - 1].is_a?(Hash)
              field_specs[i - 2] = ffi_type
            else
              field_specs[i - 1] = ffi_type
            end
            field_specs.insert(i, offset)
            i += 1

            @field_specs[name] = field_spec_class.new(name, type, offset, descriptors)
          else
            @field_specs[name] = field_spec_class.new(name, ffi_type, offset, descriptors)
          end
        end

        super(*field_specs.reject {|field_spec| field_spec.is_a?(Hash)})
      end

      def add(field_name, field_type, offset, descriptors)
        if field_type.is_a?(Integer)
          integral_type = [Type::UINT8, Type::UINT16, Type::UINT32, Type::UINT64].find {|type| field_type <= type.size * 8}

          add(field_name, "uint#{integral_type.size * 8}: #{field_type}", offset, descriptors)
        else
          if field_type.is_a?(String)
            m = /^(?<integral_type>[\w_]+)\s*:\s*(?<bits_size>\d+)$/.match(field_type.strip)
            raise "Unrecognized format #{field_type}" unless m

            integral_type, bits_size = find_field_type(m[:integral_type].to_sym), m[:bits_size].to_i
            raise "Illegal format #{field_type}" if bits_size > integral_type.size * 8

            unless @current_allocation_unit
              @current_allocation_unit = {integral_type: integral_type, bits_size: bits_size}
            else
              # Adjacent bit fields are packed into the same 1-, 2-, or 4-byte allocation unit if the integral types are the same size
              # and if the next bit field fits into the current allocation unit without crossing the boundary
              # imposed by the common alignment requirements of the bit fields.
              if integral_type.size == @current_allocation_unit[:integral_type].size
                if @current_allocation_unit[:bits_size] + bits_size <= integral_type.size * 8
                  @current_allocation_unit[:bits_size] += bits_size
                else
                  @offset += integral_type.size
                  @current_allocation_unit[:bits_size] = bits_size
                end
              else
                @offset += [integral_type.size, @current_allocation_unit[:integral_type].size].max
                @current_allocation_unit = {integral_type: integral_type, bits_size: bits_size}
              end
            end

            type = bit_field(integral_type, bits_size, @current_allocation_unit[:bits_size] - bits_size)
          else
            type = find_field_type(field_type)

            if @current_allocation_unit
              @offset += [type.size, @current_allocation_unit[:integral_type].size].max
              @current_allocation_unit = nil
            end
            @offset = (offset.nil? || offset == -1) ? @offset + type.size : offset + type.size
          end

          [type, @offset]
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

    # Set field value
    def []=(field_name, value)
      super(field_name, map_field_value(field_name, value))
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
