require 'ffi/spec_helper'
require 'ffi/struct_ex/struct_ex'


describe FFI::StructEx do
  describe "#size and #alignment" do
    def test_size_and_alignment(specs, size, alignment)
      klass = Class.new(described_class) do
        layout(*specs)
      end

      klass.size.should == size
      klass.alignment.should == alignment
    end

    it "should work by declaring ffi type" do
      test_size_and_alignment([:f0, :short,
                               :f1, :char,
                               :f2, :char], 4, 2)

      test_size_and_alignment([:f0, :short,
                               :f1, :char], 4, 2)
    end

    it "should work by only declaring bit field with default type" do
      test_size_and_alignment([:f0, 31,
                               :f1, 31], 8, 4)

      test_size_and_alignment([:f0, 8,
                               :f1, 16], 4, 2)
      test_size_and_alignment([:f0, 16,
                               :f1, 8], 4, 2)

      test_size_and_alignment([:f0, 1,
                               :f1, 16,
                               :f2, 1], 6, 2)
    end

    it "should work by declaring bit field with descriptors and offset" do
      test_size_and_alignment([:f0, 31, {'1st' => 0xff},
                               :f1, 31], 8, 4)

      test_size_and_alignment([:f0, 8, {'1st' => 0xff},
                               :f1, :short, 4, {'1st' => 0xff}], 6, 2)
    end

    it "should work by only declaring bit field with explicit type" do
      test_size_and_alignment([:f0, 'uint8: 1'], 1, 1)
      test_size_and_alignment([:f0, 'uint16: 1'], 2, 2)
      test_size_and_alignment([:f0, 'uint32: 1'], 4, 4)

      test_size_and_alignment([:f0, 'uint16: 3',
                               :f1, 'uint16: 1',
                               :f2, 'uint16: 1',
                               :f3, 'uint16: 3',
                               :f4, 'uint16: 8'], 2, 2)

      test_size_and_alignment([:f0, 'uint8: 1',
                               :f1, 'uint8: 1'], 1, 1)

      test_size_and_alignment([:f0, 'uint8: 1',
                               :f1, 'int8: 1'], 1, 1)

      test_size_and_alignment([:f0, 'uint8: 1',
                               :f1, 'uint32: 1'], 8, 4)
      test_size_and_alignment([:f0, 'uint32: 1',
                               :f1, 'uint8: 1'], 8, 4)
    end

    it "should work by declaring bit field and ffi type" do
      test_size_and_alignment([:f0, 31,
                               :f1, :uint8], 8, 4)

      test_size_and_alignment([:f0, 1,
                               :f1, :uint32], 8, 4)

      test_size_and_alignment([:f0, 4,
                               :f1, 4,
                               :f2, 8,
                               :f3, :uint8], 3, 1)

      test_size_and_alignment([:f0, 1,
                               :f1, 1,
                               :f2, :uint8], 2, 1)

      test_size_and_alignment([:f0, 1,
                               :f1, 1,
                               :f2, :uint8,
                               :f3, 1,
                               :f4, 1], 3, 1)

      test_size_and_alignment([:f0, 1,
                               :f1, 1,
                               :f2, :uint16,
                               :f3, 1,
                               :f4, 1], 6, 2)

      test_size_and_alignment([:f0, 1,
                               :f1, 1,
                               :f2, :uint16,
                               :f3, 1,
                               :f4, 8], 6, 2)

      test_size_and_alignment([:f0, 'uint32: 1',
                               :f1, :uint16], 8, 4)

      test_size_and_alignment([:f0, 'uint8: 1',
                               :f1, :uint32], 8, 4)

      test_size_and_alignment([:f0, :short,
                               :f1, 'char: 1'], 4, 2)

      test_size_and_alignment([:f0, :char,
                               :f1, 'short: 1'], 4, 2)
    end

    it "should work by declaring bit field with typedefed type and ffi type" do
      FFI.typedef :uint8, :UINT8
      test_size_and_alignment([:f0, 'UINT8: 8',
                               :f1, 'int: 1'], 8, 4)
    end
  end

  describe "#size and #alignment with pack 1" do
    def test_size_and_alignment(specs, size, alignment)
      klass = Class.new(described_class) do
        pack 1
        layout(*specs)
      end

      klass.size.should == size
      klass.alignment.should == alignment
    end

    it "should work by declaring ffi type" do
      test_size_and_alignment([:f0, :short,
                               :f1, :char,
                               :f2, :char], 4, 1)

      test_size_and_alignment([:f0, :short,
                               :f1, :char], 3, 1)
      test_size_and_alignment([:f0, :char,
                               :f1, :short], 3, 1)
    end

    it "should work by only declaring bit field with default type" do
      test_size_and_alignment([:f0, 31,
                               :f1, 31], 8, 1)

      test_size_and_alignment([:f0, 8,
                               :f1, 16], 3, 1)
      test_size_and_alignment([:f0, 16,
                               :f1, 8], 3, 1)

      test_size_and_alignment([:f0, 1,
                               :f1, 16,
                               :f2, 1], 4, 1)
    end

    it "should work by declaring bit field and ffi type" do
      test_size_and_alignment([:f0, 'uint32: 1',
                               :f1, :uint16], 6, 1)
    end
    let(:klass1) {

    }

    let(:klass1) {
      klass = Class.new(FFI::StructEx) do
                pack 1
                layout :bits_0_2, 'uint16: 3',
                        :bit_3,    'uint16: 1',
                        :bit_4,    'uint16: 1',
                        :bits_5_7, 'uint16: 3',
                        :bits_8_15, :uint8
              end
      Class.new(FFI::StructEx) do
        pack 1
        layout :f0, klass,
               :f1, :uint8,
               :f2, :uint8,
               :f3, :uint8
      end
    }

    let(:klass2) {
      klass = Class.new(FFI::StructEx) do
                layout :bits_0_2, 'uint16: 3',
                        :bit_3,    'uint16: 1',
                        :bit_4,    'uint16: 1',
                        :bits_5_7, 'uint16: 3',
                        :bits_8_15, :uint8
              end
      Class.new(FFI::StructEx) do
        pack 1
        layout :f0, klass,
               :f1, :uint8,
               :f2, :uint8,
               :f3, :uint8
      end
    }

    it "should work by declaring embedded field" do
      klass1.size.should == 6
      klass1.offset_of(:f1).should == 3

      klass2.size.should == 7
      klass2.offset_of(:f1).should == 4
    end
  end

  describe "#==" do
    context "when given embedded struct" do
      let(:hash) { {f0: {bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011}, f1: 0x1} }

      subject {
        Class.new(described_class) do
          layout :f0, struct_ex(:bits_0_2, 3,
                                     :bit_3,    1,
                                     :bit_4,    1,
                                     :bits_5_7, 3),
                 :f1, :uint8
        end.new(hash)
      }

      it "should equal to hash" do
        subject.should == hash
        subject[:f0].to_ptr.read_uint8.should == 0b0110_1001
        subject[:f1].should == hash[:f1]
      end
    end
  end

  describe "#initialize" do
    let(:klass) {
      Class.new(described_class) do
        layout :f0, struct_ex(:bits_0_2, 3,
                              :bit_3,    1,
                              :bit_4,    1,
                              :bits_5_7, 3),
               :f1, :uint8
      end
    }

    context "when given empty parameters" do
      subject { klass.new }

      it "should be initialized as 0" do
        subject[:f0].pointer.read_uint8.should == 0
        subject[:f1].should == 0
      end
    end

    context "when given hash" do
      let(:hash) { {f0: {bits_0_2: 0b111, bit_3: 0b0, bit_4: 0b0, bits_5_7: 0b101}, f1: 0x12} }
      subject { klass.new(hash) }

      it "should be initialized as hash" do
        subject.should == hash
        subject[:f0].should == hash[:f0]
        subject[:f0].pointer.read_uint8.should == 0b101_0_0_111
        subject[:f1].should == hash[:f1]
      end
    end
  end

  describe "#[]" do
    context "when given signed integer type" do
      let(:klass) {
        Class.new(FFI::StructEx) do
          layout :f0, 'uint8: 3',
                 :f1, 'char: 1',
                 :f2, 'uint8: 1',
                 :f3, 'char: 3'
        end
      }

      subject { klass.new(f0: 0b001, f1: 0b1, f2: 0b1, f3: 0b100) }

      it "should be read as signed integer" do
        subject[:f0].should == 1
        subject[:f1].should == -1
        subject[:f2].should == 1
        subject[:f3].should == -4

        subject[:f3] = 0b010
        subject[:f3].should == 2

        subject[:f3] = 0
        subject[:f3].should == 0

        subject[:f3] = 0b110
        subject[:f3].should == -2
      end
    end
  end

  describe "#[]=" do
    context "when given ffi type struct with textual descriptors" do
      let(:klass) {
        Class.new(FFI::StructEx) do
          layout :f0, :uint8, {'all_1' => 0xff, 'all_0' => 0x00},
                 :f1, :uint8, {3 => 1}
        end
      }

      subject { klass.new(f0: 'all_1', f1: 0x12) }

      it "should be written with textual descriptor" do
        subject[:f0].should == 0xff
        subject[:f1].should == 0x12

        subject[:f0] = 'all_0'
        subject[:f0].should == 0x00

        subject[:f0] = 0x12
        subject[:f0].should == 0x12

        subject[:f1] = 3
        subject[:f1].should == 1
      end
    end

    context "when given bit field type struct with textual descriptors" do
      let(:klass) {
        Class.new(FFI::StructEx) do
          layout :f0, 3, {'all_1' => 0b111, 'all_0' => 0b000},
                 :f1, 1, {'yes' => 0b1, 'no' => 0b0},
                 :f2, 1,
                 :f3, :uint8
        end
      }

      subject { klass.new(f0: 'all_1', f1: 'yes') }

      it "should be written with textual descriptor" do
        subject[:f0].should == 0b111
        subject[:f1].should == 0b1
        subject[:f2].should == 0
        subject[:f3].should == 0

        subject[:f0] = 'all_0'
        subject[:f0].should == 0x00

        subject[:f0] = 0b010
        subject[:f0].should == 0b010

        subject[:f1] = 'no'
        subject[:f1].should == 0

        subject[:f1] = 1
        subject[:f1].should == 1
      end
    end

    context "when given embedded struct" do
      let(:klass) {
        Class.new(FFI::StructEx) do
          layout :f0, struct_ex(:bits_0_2, 'uint16: 3',
                                :bit_3,    'uint16: 1',
                                :bit_4,    'uint16: 1',
                                :bits_5_7, 'uint16: 3',
                                :bits_8_15, :uint8),
                 :f1, :uint8,
                 :f2, :uint8,
                 :f3, :uint8
        end
      }

      subject { klass.new }

      it "should be written for embeded field" do
        klass.offset_of(:f1).should == 4

        subject[:f0].class.superclass.should == FFI::StructEx
        subject[:f0].size.should == 4
        subject[:f0].alignment.should == 2

        subject[:f0].to_ptr.write_uint16(0b0110_1001)
        subject[:f0].to_ptr.read_uint16.should == 0b0110_1001
        subject[:f0][:bits_0_2].should == 0b001

        subject[:f0][:bits_0_2] = 0b101
        subject[:f0][:bits_0_2].should == 0b101
        subject[:f0].to_ptr.read_uint16.should == 0b0110_1101

        subject[:f0] = {bits_0_2: 0b001, bit_3: 0b1, bit_4: 0b0, bits_5_7: 0b011}
        subject[:f0].to_ptr.read_uint16.should == 0b0110_1001
        subject[:f0][:bits_0_2].should == 0b001
      end
    end
  end

  describe "#pointer.write" do
    let(:klass) {
      Class.new(FFI::StructEx) do
        layout :f0, 3,
               :f1, 1,
               :f2, 1,
               :f3, 3
      end
    }

    subject { klass.new }

    it "should write" do
      subject.pointer.write_uint8(0b0110_1001)

      subject[:f0].should == 0b001
      subject[:f1].should == 0b1
      subject[:f2].should == 0b0
      subject[:f3].should == 0b011
    end
  end
end

