# FFI::StructEx

The gem adds bit field for C struct by FFI::StructEx inherited from FFI::Struct. The functionality is limited now, refer to usage section for supported forms.

## Installation

Add this line to your application's Gemfile:

    gem 'ffi-struct_ex'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ffi-struct_ex

## Usage

* Struct (only support "unsigned" field)

```ruby
require 'ffi/struct_ex'

class Subject < FFI::StructEx
  layout :bits_0_2, 3,
         :bit_3,    1,
         :bit_4,    1,
         :bits_5_7, 3
end

subject = Subject.new(bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011)

subject[:bits_0_2] #=> 0b101
subject.read #=> 0b0110_1001
```

* Struct (embedded bit fields)

```ruby
require 'ffi/struct_ex'

class Subject < FFI::StructEx
  layout :field_0, bit_fields(:bits_0_2, 3,
                              :bit_3,    1,
                              :bit_4,    1,
                              :bits_5_7, 3),
         :field_1, :uint8,
         :field_2, :uint8,
         :field_3, [:uint8, 2]
end

subject[:field_0].class.superclass #=> FFI::StructEx

subject[:field_0] = 0b0110_1001
subject[:field_0].read #=> 0b0110_1001

subject[:field_0][:bits_0_2] = 0b101
subject[:field_0][:bits_0_2] #=> 0b101
subject[:field_0].read #=> 0b0110_1101

subject[:field_0] = {bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011}
subject[:field_0].read #=> 0b0110_1001

subject[:field_0] == {bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011} #=> true
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
