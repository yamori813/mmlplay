# mruby mml player for i2c psg/ssc module
# Hiroki Mori 2016/09/08

Into0="o6l16q15 eere rcer gr8. < gr8."
Into1="o5l16q15 f#f#rf# rf#f#r gr8. <gr8."
Into2="o4l16q15 ddrd rddr >br8. <gr8."

def tone(t, ch, key)
  note = [
    0xD5C, 0xC9D, 0xBE7, 0xB3C, 0xA9B, 0xA02, 0x973, 0x8EB, 0x86B, 
    0x7F2, 0x780, 0x714,
    0x6AE, 0x64E, 0x5F4, 0x59E, 0x54D, 0x501, 0x4B9, 0x475, 0x435,
    0x3F9, 0x3C0, 0x38A,
    0x357, 0x327, 0x2FA, 0x2CF, 0x2A7, 0x281, 0x25D, 0x23B, 0x21B,
    0x1FC, 0x1E0, 0x1C5,
    0x1AC, 0x194, 0x17D, 0x168, 0x153, 0x140, 0x12E, 0x11D, 0x10D,
    0xFE, 0xF0, 0xE2,
    0xD6, 0xCA, 0xBE, 0xB4, 0xAA, 0xA0, 0x97, 0x8F, 0x87,
    0x7F, 0x78, 0x71,
    0x6B, 0x65, 0x5F, 0x5A, 0x55, 0x50, 0x4C, 0x47, 0x43,
    0x40, 0x3C, 0x39,
    0x35, 0x32, 0x30, 0x2D, 0x2A, 0x28, 0x26, 0x24, 0x22,
    0x20, 0x1E, 0x1C,
    0x1B, 0x19, 0x18, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11,
    0x10, 0xF, 0xE,
  ]
  num = note[key-12]
  t.write(0x50,ch*2,num & 0xff)
  t.write(0x50,ch*2+1,num >> 8)
  t.write(0x50,8+ch,0x0f)
end

class MML
  @@tempo

  @oct
  @len
  @gat
 
  @dat
  @curpos

  def self.gettempo
    return @@tempo
  end

  def initialize(str)
    @dat = str

    @@tempo = 120
    @oct = 5
    @len = 0
    @gat = 0.98
    @curpos = 0
  end

  def getnum(off)
    if (@dat.length == off || @dat[off] < '0' || @dat[off] > '9') then
      return -1, off
    else
      num = 0;
      while @dat.length != off && @dat[off] >= '0' && @dat[off] <= '9'
        num *= 10
        e = @dat[off, 1]
        num += e.to_i
        off += 1
      end
      return num, off
    end
  end

  def getlen(off)
    if (@dat.length == off || @dat[off] < '0' || @dat[off] > '9') then
      len = @len
      return len, off
    else
      num = 0;
      while @dat.length != off && @dat[off] >= '0' && @dat[off] <= '9'
        num *= 10
        e = @dat[off, 1]
        num += e.to_i
        off += 1
      end
      len = 480 / num
      if @dat[off] == "."  then
        len = len / 2 * 3
        off += 1
      end
      return len, off
    end
  end

  def getnext()
    note = { "c" => 0, "c#" => 1, "d" => 2, "d#" => 3, "e" => 4, "f" => 5,
      "f#" => 6, "g" => 7, "g#" => 8, "a" => 9, "a#" => 10, "b" => 11,
      "db" => 1, "eb" => 3, "gb" => 6, "ab" => 8, "bb" => 10,
      "cb" => -1}
   
    while true
      e = @dat[@curpos, 1].downcase
# p e
      if e == "o" then
        n, off = getnum(@curpos + 1)
        @oct = n
        @curpos = off
      elsif e == "<" then
        @oct -= 1
        @curpos += 1
      elsif e == ">" then
        @oct += 1
        @curpos += 1
      elsif e == "l" then
        n, off = getlen(@curpos + 1)
        @len = n
        @curpos = off
      elsif e == "q" then
        n, off = getnum(@curpos + 1)
        @gat = n / (480 / @len)
        @curpos = off
      elsif e == "v" then
        n, off = getnum(@curpos + 1)
        @curpos = off
      elsif e == "t" then
        n, off = getnum(@curpos + 1)
        @@temp = n
        @curpos = off
      elsif e == "n" then
        n, off = getnum(@curpos + 1)
        @curpos = off
      elsif e == " " then
        @curpos += 1
      elsif e == "@" then
        @curpos += 2
        n, off = getnum(@curpos + 1)
        @curpos = off
      elsif e >= 'a' && e <= 'g' then
        if @dat[@curpos + 1, 1] == "#" || @dat[@curpos + 1, 1] == "+" then
          key = e + "#"
          @curpos += 1
        elsif @dat[@curpos + 1, 1] == "-" then
          key = e + "b"
          @curpos += 1
        else
          key = e
        end
        n, off = getlen(@curpos + 1)
        @curpos = off
        return @oct * 12 + note[key], n, @len - (@len * @gat).to_i
      elsif e == "r" then
        n, off = getlen(@curpos + 1)
        @curpos = off
        return -1, n, 0
      else
        return -1
      end
    end
  end
end

class TRACK
  @curev
  @dat

  def initialize(mml)
    @dat = mml
    @curev = -1
  end

  def func(t, ch)
    if @curev == -1 || @curev[1] == 0  then
      @curev = @dat.getnext()
      if @curev == -1 then
        return -1
      end
      if @curev[0] != -1 then
        tone(t, ch, @curev[0])
      end
    elsif @curev[0] != -1 && @curev[1] == @curev[2] then
      t.write(0x50,0x08+ch,0x00)
      @curev[1] -= 1
    else
      @curev[1] -= 1
    end
  end
end

# main

mml0 = MML.new(Into0)
mml1 = MML.new(Into1)
mml2 = MML.new(Into2)

tr0 = TRACK.new(mml0)
tr1 = TRACK.new(mml1)
tr2 = TRACK.new(mml2)

t = BsdIic.new(0)
t.write(0x50,0x07,0xf8) 

while 1

  if tr0.func(t, 0) == -1 then
    break
  end

  if tr1.func(t, 1) == -1 then
    break
  end

  if tr2.func(t, 2) == -1 then
    break
  end

  tick = (60*1000*1000/(MML::gettempo*120)).to_i
  Sleep::usleep(tick)
end
