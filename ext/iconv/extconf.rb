require 'mkmf'

dir_config("iconv")

conf = File.exist?(File.join($srcdir, "config.charset"))
conf = with_config("config-charset", enable_config("config-charset", conf))

if have_header("iconv.h")
  if !try_compile("", "-Werror") or checking_for("const of iconv() 2nd argument") do
      !try_compile('
#include <iconv.h>
size_t
test(iconv_t cd, char **inptr, size_t *inlen, char **outptr, size_t *outlen)
{
    return iconv(cd, inptr, inlen, outptr, outlen);
}
', "-Werror")
    end
    $defs.push('-DICONV_INPTR_CAST=""')
  else
    $defs.push('-DICONV_INPTR_CAST="(char **)"')
  end
  have_library("iconv", "iconv") {|s| s.sub(/(?=\n\/\*top\*\/)/, "#include <iconv.h>")}
  if conf
    prefix = '$(srcdir)'
    prefix =  $nmake ? "{#{prefix}}" : "#{prefix}/"
    wrapper = "./iconv.rb"
    $INSTALLFILES = [[wrapper, "$(RUBYARCHDIR)"]]
    if String === conf
      require 'uri'
      scheme = URI.parse(conf).scheme
    else
      conf = prefix + "config.charset"
    end
    $cleanfiles << wrapper
  end
  create_makefile("iconv")
  if conf
    open("Makefile", "a") do |mf|
      mf.print("\nall: #{wrapper}\n\n#{wrapper}: #{prefix}charset_alias.rb")
      mf.print(" ", conf) unless scheme
      mf.print("\n\t$(RUBY) ", prefix, "charset_alias.rb ", conf, " $@\n")
    end
  end
end
