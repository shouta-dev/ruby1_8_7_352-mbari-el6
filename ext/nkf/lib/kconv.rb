#
# kconv.rb - Kanji Converter.
#
# $Id$
#

require 'nkf'

module Kconv
  #
  # Public Constants
  #
  
  #Constant of Encoding
  AUTO = ::NKF::AUTO
  JIS = ::NKF::JIS
  EUC = ::NKF::EUC
  SJIS = ::NKF::SJIS
  BINARY = ::NKF::BINARY
  NOCONV = ::NKF::NOCONV
  ASCII = ::NKF::ASCII
  UTF8 = ::NKF::UTF8
  UTF16 = ::NKF::UTF16
  UTF32 = ::NKF::UTF32
  UNKNOWN = ::NKF::UNKNOWN
  
  #
  # Private Constants
  #
  
  #Regexp of Encoding
  RegexpShiftjis = /\A(?:
		       [\x00-\x7f\xa1-\xdf] |
		       [\x81-\x9f\xe0-\xfc][\x40-\x7e\x80-\xfc] 
		      )*\z/nx
  RegexpEucjp = /\A(?:
		    [\x00-\x7f]                         |
		    \x8e        [\xa1-\xdf]             |
		    \x8f        [\xa1-\xdf] [\xa1-\xfe] |
		    [\xa1-\xdf] [\xa1-\xfe]
		   )*\z/nx
  RegexpUtf8  = /\A(?:
		    [\x00-\x7f]                                     |
		    [\xc2-\xdf] [\x80-\xbf]                         |
		    \xe0        [\xa0-\xbf] [\x80-\xbf]             |
		    [\xe1-\xef] [\x80-\xbf] [\x80-\xbf]             |
		    \xf0        [\x90-\xbf] [\x80-\xbf] [\x80-\xbf] |
		    [\xf1-\xf3] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] |
		    \xf4        [\x80-\x8f] [\x80-\xbf] [\x80-\xbf]
		   )*\z/nx
  
  SYMBOL_TO_OPTION = {
    :iso2022jp	=> '-j',
    :jis	=> '-j',
    :eucjp	=> '-e',
    :euc	=> '-e',
    :eucjpms	=> '-e --cp932',
    :shiftjis	=> '-s',
    :sjis	=> '-s',
    :cp932	=> '-s --cp932',
    :windows31j	=> '-s --cp932',
    :utf8	=> '-w',
    :utf8bom	=> '-w8',
    :utf8n	=> '-w80',
    :utf16	=> '-w16',
    :utf16be	=> '-w16B',
    :utf16ben	=> '-w16B0',
    :utf16le	=> '-w16L',
    :utf16len	=> '-w16L0',
    :noconv	=> '-t',
    :lf		=> '-Lu',	# LF
    :cr		=> '-Lm',	# CR
    :crlf	=> '-Lw',	# CRLF
    :fj		=> '--fj',	# for fj
    :unix	=> '--unix',	# for unix
    :mac	=> '--mac',	# CR
    :windows	=> '--windows',	# CRLF
    :mime	=> '--mime',	# MIME encode
    :base64	=> '--base64',	# BASE64 encode
    :x0201	=> '--x',	# Hankaku to Zenkaku Conversion off
    :nox0201	=> '--X',	# Hankaku to Zenkaku Conversion on
    :x0212	=> '--x0212',	# Convert JISX0212 (Hojo Kanji)
    :hiragana	=> '--hiragana',# Katakana to Hiragana Conversion
    :katakana	=> '--katakana',# Hiragana to Katakana Conversion
    :capinput		=> '--cap-input',	# Convert hex after ':'
    :urlinput		=> '--url-input',	# decode percent-encoded octets
    :numcharinput	=> '--numchar-input'	# Convert Unicode Character Reference
  }
  
  CONSTANT_TO_SYMBOL = {
    JIS		=> :iso2022jp,
    EUC		=> :eucjp,
    SJIS	=> :shiftjis,
    BINARY	=> :binary,
    NOCONV	=> :noconv,
    ASCII	=> :ascii,
    UTF8	=> :utf8,
    UTF16	=> :utf16,
    UTF32	=> :utf32,
    UNKNOWN	=> :unknown
  }
  
  SYMBOL_TO_CONSTANT = {
    :auto	=> AUTO,
    :unknown	=> UNKNOWN,
    :binary	=> BINARY,
    :ascii	=> ASCII,
    :ascii	=> ASCII,
    :shiftjis	=> SJIS,
    :sjis	=> SJIS,
    :cp932	=> SJIS,
    :eucjp	=> EUC,
    :euc	=> EUC,
    :eucjpms	=> EUC,
    :iso2022jp	=> JIS,
    :jis	=> JIS,
    :utf8	=> UTF8,
    :utf8n	=> UTF8,
    :utf16	=> UTF16,
    :utf16be	=> UTF16,
    :utf16ben	=> UTF16,
    :utf16le	=> UTF16,
    :utf16len	=> UTF16,
    :noconv	=> NOCONV
  }
  
  #
  # Public Methods
  #
  
  #
  # kconv
  #
  
  def kconv(str, out_code, in_code = AUTO)
    opt = '-'
    case in_code
    when ::NKF::JIS
      opt << 'J'
    when ::NKF::EUC
      opt << 'E'
    when ::NKF::SJIS
      opt << 'S'
    when ::NKF::UTF8
      opt << 'W'
    when ::NKF::UTF16
      opt << 'W16'
    end

    case out_code
    when ::NKF::JIS
      opt << 'j'
    when ::NKF::EUC
      opt << 'e'
    when ::NKF::SJIS
      opt << 's'
    when ::NKF::UTF8
      opt << 'w'
    when ::NKF::UTF16
      opt << 'w16'
    when ::NKF::NOCONV
      return str
    end

    opt = '' if opt == '-'

    ::NKF::nkf(opt, str)
  end
  module_function :kconv

  #
  # Kconv.conv( str, :to => :"euc-jp", :from => :shift_jis, :opt => [:hiragana,:katakana] )
  #
  def conv(str, *args)
    option = nil
    if args[0].is_a? Hash
      option = [
	args[0][:to]||args[0]['to'],
	args[0][:from]||args[0]['from'],
	args[0][:opt]||args[0]['opt'] ]
    elsif args[0].is_a? String or args[0].is_a? Symbol or args[0].is_a? Integer
      option = args
    else
      return str
    end
    
    to = symbol_to_option(option[0])
    from = symbol_to_option(option[1]).to_s.sub(/(-[jesw])/o){$1.upcase}
    opt = Array.new
    if option[2].is_a? Array
      opt << option[2].map{|x|symbol_to_option(x)}.compact.join('')
    elsif option[2].is_a? String
      opt << option[2]
    end
    
    nkf_opt = ('-x -m0 %s %s %s' % [to, from, opt.join(' ')])
    result = ::NKF::nkf( nkf_opt, str)
  end
  module_function :conv

  #
  # Encode to
  #

  def tojis(str)
    ::NKF::nkf('-j', str)
  end
  module_function :tojis

  def toeuc(str)
    ::NKF::nkf('-e', str)
  end
  module_function :toeuc

  def tosjis(str)
    ::NKF::nkf('-s', str)
  end
  module_function :tosjis

  def toutf8(str)
    ::NKF::nkf('-w', str)
  end
  module_function :toutf8

  def toutf16(str)
    ::NKF::nkf('-w16', str)
  end
  module_function :toutf16

  alias :to_jis :tojis
  alias :to_euc :toeuc
  alias :to_eucjp :toeuc
  alias :to_sjis :tosjis
  alias :to_shiftjis :tosjis
  alias :to_iso2022jp :tojis
  alias :to_utf8 :toutf8
  alias :to_utf16 :toutf16

  #
  # guess
  #

  def guess(str)
    ::NKF::guess(str)
  end
  module_function :guess

  def guess_old(str)
    ::NKF::guess1(str)
  end
  module_function :guess_old

  def guess_as_symbol(str)
    CONSTANT_TO_SYMBOL[guess(str)]
  end
  module_function :guess_as_symbol

  #
  # isEncoding
  #

  def iseuc(str)
    RegexpEucjp.match( str )
  end
  module_function :iseuc
  
  def issjis(str)
    RegexpShiftjis.match( str )
  end
  module_function :issjis

  def isutf8(str)
    RegexpUtf8.match( str )
  end
  module_function :isutf8

  #
  # encoding?
  #

  def eucjp?(str)
    RegexpEucjp.match( str ) ? true : false
  end
  module_function :eucjp?

  def shiftjis?(str)
    RegexpShiftjis.match( str ) ? true : false
  end
  module_function :shiftjis?
  def utf8?(str)
    RegexpUtf8.match( str ) ? true : false
  end
  module_function :utf8?
  alias :euc? :eucjp?
  alias :sjis? :shiftjis?
  module_function :euc?
  module_function :sjis?


  #
  # Private Methods
  #
  
  def symbol_to_option(symbol)
    if symbol.to_s[0] == ?-
      return symbol.to_s
    elsif symbol.is_a? Integer
      symbol = CONSTANT_TO_SYMBOL[symbol]
    end
    begin
      SYMBOL_TO_OPTION[ symbol.to_s.downcase.delete('-_').to_sym ]
    rescue
      return nil
    end
  end
private :symbol_to_option
  module_function :symbol_to_option
end

class String
  def kconv(out_code, in_code=Kconv::AUTO)
    Kconv::kconv(self, out_code, in_code)
  end
  
  def conv(*args)
    Kconv::conv(self, *args)
  end
  
  # to Encoding
  def tojis
    ::NKF::nkf('-j', self)
  end
  def toeuc
    ::NKF::nkf('-e', self)
  end
  def tosjis
    ::NKF::nkf('-s', self)
  end
  def toutf8
    ::NKF::nkf('-w', self)
  end
  def toutf16
    ::NKF::nkf('-w16', self)
  end
  alias :to_jis :tojis
  alias :to_euc :toeuc
  alias :to_eucjp :toeuc
  alias :to_sjis :tosjis
  alias :to_shiftjis :tosjis
  alias :to_iso2022jp :tojis
  alias :to_utf8 :toutf8
  alias :to_utf16 :toutf16
  
  # is Encoding
  def iseuc;	Kconv.iseuc( self ) end
  def issjis;	Kconv.issjis( self ) end
  def isutf8;	Kconv.isutf8( self ) end
  def eucjp?;	Kconv.eucjp?( self ) end
  def shiftjis?;Kconv.shiftjis?( self ) end
  def utf8?;	Kconv.utf8?( self ) end
  alias :euc? :eucjp?
  alias :sjis? :shiftjis?
  
  def guess_as_symbol;	Kconv.guess_as_symbol( self ) end
end
