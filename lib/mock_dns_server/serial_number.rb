# Handles serial values, adjusting correctly for wraparound.
#
# From the DNS and Bind book, p. 139:
#
# "The DNS serial number is a
# 32-bit unsigned integer whose value ranges from 0 to 4,294,967,295. The serial number
# uses sequence space arithmetic, which means that for any serial number, half the
# numbers in the number space (2,147,483,647 numbers) are less than the serial number,
# and half the numbers are larger.""

class SerialNumber


  MIN_VALUE      =  0
  MAX_VALUE      = 0xFFFF_FFFF  # (4_294_967_295)
  MAX_DIFFERENCE = 0x8000_0000  # (2_147_483_648)

  attr_accessor :value

  def initialize(value)
    self.class.validate(value)
    @value = value
  end


  # Call this when you have an object that may be either a SerialNumber
  # or a Fixnum/Bignum, and you want to ensure that you have
  # a SerialNumber.
  def self.object(thing)
    if thing.is_a?(SerialNumber)
      thing
    elsif thing.nil?
      nil
    else
      SerialNumber.new(thing)
    end
  end


  def self.validate(value)
    if value < MIN_VALUE || value > MAX_VALUE
      raise "Invalid value (#{value}), must be between #{MIN_VALUE} and #{MAX_VALUE}."
    end
  end


  def self.compare_values(value_1, value_2)
    distance = (value_1 - value_2).abs

    if distance == 0
      0
    elsif distance < MAX_DIFFERENCE
      value_1 - value_2
    elsif distance > MAX_DIFFERENCE
      value_2 - value_1
    else # distance == MAX_DIFFERENCE
      raise "Cannot compare 2 numbers whose difference is exactly #{MAX_DIFFERENCE.to_s(16)} (#{value_1}, #{value_2})."
    end
  end


  def self.compare(sss1, sss2)
    compare_values(sss1.value, sss2.value)
  end


  def self.next_serial_value(value)
    validate(value)
    value == MAX_VALUE ? 0 : value + 1
  end


  def next_serial
    self.class.new(self.class.next_serial_value(value))
  end


  def <=>(other)
    self.class.compare(self, other)
  end


  def >(other)
    self.<=>(other) > 0
  end


  def <(other)
    self.<=>(other) < 0
  end


  def >=(other)
    self.<=>(other) >= 0
  end


  def <=(other)
    self.<=>(other) <= 0
  end


  def ==(other)
    self.class == other.class &&
    self.value == other.value
  end


  def hash
    value.hash
  end

  def eql?(other)
    self.==(other)
  end

  # Can be used to normalize an object that may be a Fixnum or a SerialNumber to an int:
  def to_i
    value
  end


  def to_s
    "#{self.class}: value = #{value}"
  end

end


