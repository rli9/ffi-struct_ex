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

module FFI
  class StructEx < FFI::Struct
    BitLayout = ::Struct.new(:name, :bits, :offset, :texts)

    class << self
      def bit_fields(*descs)
        struct_class = Class.new(StructEx) do
          layout(*descs)
        end

        bit_fields_class = Class.new(FFI::StructLayout::Field) do
          def initialize(name, offset, type)
            #TODO use a different native_type to avoid dummy field for struct
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
          end

          self.struct_class = struct_class
        end
      end

      attr_reader :bits_size, :bit_layouts

      def layout(*descs)
        if descs.size == 0 || !descs[1].is_a?(Integer)
          super(*descs)
          @bits_size = self.size * 8
        else
          @bit_layouts = {}

          index = @bits_size = 0

          while index < descs.size
            bit_field_name, bits, texts = descs[index, 3]

            if texts.kind_of?(Hash)
              @bit_layouts[bit_field_name] = BitLayout.new(bit_field_name, bits, @bits_size, texts)
              index += 3
            else
              @bit_layouts[bit_field_name] = BitLayout.new(bit_field_name, bits, @bits_size)
              index += 2
            end

            @bits_size += bits
          end

          #FIXME consider 24 bits situation or larger than 32 bits
          #FIXME remove dummy field or have a better name for this field
          super(:dummy, "uint#{bytes_size * 8}".to_sym)
        end
      end

      def bytes_size
        (bits_size + 7) >> 3
      end

      def alignment
        return super unless self.bit_layouts
        #FIXME consider 24 bits situation
        FFI.find_type("uint#{bytes_size * 8}".to_sym).alignment
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

    def [](bit_field_name)
      return super unless self.class.bit_layouts && self.class.bit_layouts.keys.include?(bit_field_name)

      bit_layout = self.class.bit_layouts[bit_field_name]
      mask = ((1 << bit_layout.bits) - 1) << bit_layout.offset

      (self.read & mask) >> bit_layout.offset
    end

    def []=(bit_field_name, value)
      return super unless self.class.bit_layouts && self.class.bit_layouts.keys.include?(bit_field_name)

      value = look_for_value(bit_field_name, value)

      bit_layout = self.class.bit_layouts[bit_field_name]
      mask = ((1 << bit_layout.bits) - 1) << bit_layout.offset

      self.write((self.read & (-1 - mask)) | ((value << bit_layout.offset) & mask))
    end

    def write(value)
      if value.is_a?(Integer)
        to_ptr.write_array_of_uint8(value.to_bytes(self.class.bytes_size))
      elsif value.is_a?(Hash)
        value.each do |bit_field_name, v|
          self[bit_field_name] = v if self.class.bit_layouts.keys.include? bit_field_name
        end
      end
    end

    def read
      bytes = to_ptr.read_array_of_uint8(self.class.bytes_size)
      bytes.reverse.inject(0) {|value, n| (value << 8) | n}
    end

    def size
      self.class.bytes_size
    end

    def ==(other)
      if other.is_a?(Integer)
        self.read == other
      elsif other.is_a?(String)
        other = other.downcase
        value = case other
          when /^\d+$/
            other.to_i
          when /^0x[\da-fA-F_]+$/
            other.to_i(16)
          when /^0b[_01]+$/
            other.to_i(2)
        end
        self.==(value)
      elsif other.is_a?(Hash)
        other.all? {|k, v| self[k] == self.look_for_value(k, v)}
      else
        super
      end
    end

    def look_for_value(bit_field_name, value)
      #FIXME add error handling
      if value.kind_of?(Integer)
        value
      elsif value.kind_of?(String)
        #FIXME this requires texts hash to have downcase key
        value = value.downcase
        if self.class.bit_layouts[bit_field_name].texts && self.class.bit_layouts[bit_field_name].texts[value]
          self.class.bit_layouts[bit_field_name].texts[value]
        else
          case value
            when /^\d+$/
              value.to_i
            when /^0x[\da-fA-F_]+$/
              value.to_i(16)
            when /^0b[01_]+$/
              value.to_i(2)
          end
        end
      else
        value
      end
    end
  end
end
