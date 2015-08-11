When /^I see and accept the Unsafe Browser start verification$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('GnomeQuestionDialogIcon.png', 30)
  @screen.type(Sikuli::Key.ESC)
end

def supported_torbrowser_languages
  langs = Array.new
  exts = @vm.execute_successfully(
    "find /usr/local/share/tor-browser-extensions -maxdepth 1 -name 'langpack*.xpi' -printf \"%f\n\"").stdout

  # Some of the TBB languages are shipped with both a language and country code, e.g. es-ES.
  # We'll only keep track of the language code and let `guess_best_tor_browser_locale`
  # try to get by with our approximated locales.
  supported_langs = exts.scan(/langpack-([a-z]+).*/).flatten
  locales = @vm.execute_successfully(
    "find /usr/lib/locale -maxdepth 1 -name '*.utf8' -printf \"%f\n\"").stdout.split

  # Determine a valid locale for each language that we want to test.
  supported_langs.each do |lang|
    # If a language shipped by TBB is not a supported system locale (e.g. 'vi'),
    # 'find(nomatch)' will use the locale xx_XX for language 'xx'.
    nomatch = proc { "#{lang}_#{lang.upcase}.utf8" }
    langs << locales.find(nomatch) { |l| l.match(/^#{lang}/) }
  end
  return langs
end

Then /^I start the Unsafe Browser in the "([^"]+)" locale$/ do |loc|
  next if @skip_steps_while_restoring_background
  step "I run \"LANG=#{loc} LC_ALL=#{loc} sudo unsafe-browser\" in GNOME Terminal"
  step "I see and accept the Unsafe Browser start verification"
end

Then /^the Unsafe Browser works in all supported languages$/ do
  next if @skip_steps_while_restoring_background
  failed = Array.new
  supported_torbrowser_languages.each do |lang|
    step "I start the Unsafe Browser in the \"#{lang}\" locale"
    begin
      step "the Unsafe Browser has started"
    rescue RuntimeError
      failed << lang
      next
    end
    step "I close the Unsafe Browser"
    step "the Unsafe Browser chroot is torn down"
  end
  assert(failed.empty?, "Unsafe Browser failed to launch in the following locale(s): #{failed.join(', ')}")
end

Then /^I see the Unsafe Browser start notification and wait for it to close$/ do
  next if @skip_steps_while_restoring_background
  notification_helper('UnsafeBrowserStartNotification.png', 30)
  @screen.waitVanish("UnsafeBrowserStartNotification.png", 10)
end

Then /^the Unsafe Browser has started$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserHomepage.png", 360)
end

Then /^the Unsafe Browser has no add-ons installed$/ do
  next if @skip_steps_while_restoring_background
  step "I open the address \"about:addons\" in the Unsafe Browser"
  step "I see \"UnsafeBrowserNoAddons.png\" after at most 30 seconds"
end

Then /^the Unsafe Browser has only Firefox's default bookmarks configured$/ do
  next if @skip_steps_while_restoring_background
  info = xul_application_info("Unsafe Browser")
  # "Show all bookmarks"
  @screen.type("o", Sikuli::KeyModifier.SHIFT + Sikuli::KeyModifier.CTRL)
  @screen.wait_and_click("UnsafeBrowserExportBookmarksButton.png", 20)
  @screen.wait_and_click("UnsafeBrowserExportBookmarksMenuEntry.png", 20)
  @screen.wait("UnsafeBrowserExportBookmarksSavePrompt.png", 20)
  path = "/home/#{info[:user]}/bookmarks"
  @screen.type(path + Sikuli::Key.ENTER)
  chroot_path = "#{info[:chroot]}/#{path}.json"
  try_for(10) { @vm.file_exist?(chroot_path) }
  dump = JSON.load(@vm.file_content(chroot_path))

  def check_bookmarks_helper(a)
    mozilla_uris_counter = 0
    places_uris_counter = 0
    a.each do |h|
      h.each_pair do |k, v|
        if k == "children"
          m, p = check_bookmarks_helper(v)
          mozilla_uris_counter += m
          places_uris_counter += p
        elsif k == "uri"
          uri = v
          if uri.match("^https://www\.mozilla\.org/")
            mozilla_uris_counter += 1
          elsif uri.match("^place:(sort|folder|type)=")
            places_uris_counter += 1
          else
            raise "Unexpected Unsafe Browser bookmark for '#{uri}'"
          end
        end
      end
    end
    return [mozilla_uris_counter, places_uris_counter]
  end

  mozilla_uris_counter, places_uris_counter =
    check_bookmarks_helper(dump["children"])
  assert_equal(5, mozilla_uris_counter,
               "Unexpected number (#{mozilla_uris_counter}) of mozilla " \
               "bookmarks")
  assert_equal(3, places_uris_counter,
               "Unexpected number (#{places_uris_counter}) of places " \
               "bookmarks")
  @screen.type(Sikuli::Key.F4, Sikuli::KeyModifier.ALT)
end

Then /^the Unsafe Browser has a red theme$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserRedTheme.png", 10)
end

Then /^the Unsafe Browser shows a warning as its start page$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserStartPage.png", 10)
end

When /^I start the Unsafe Browser$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "UnsafeBrowser" via the GNOME "Internet" applications menu'
end

When /^I successfully start the Unsafe Browser$/ do
  next if @skip_steps_while_restoring_background
  step "I start the Unsafe Browser"
  step "I see and accept the Unsafe Browser start verification"
  step "I see the Unsafe Browser start notification and wait for it to close"
  step "the Unsafe Browser has started"
end

Then /^I see a warning about another instance already running$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('UnsafeBrowserWarnAlreadyRunning.png', 10)
end

When /^I close the Unsafe Browser$/ do
  next if @skip_steps_while_restoring_background
  @screen.type("q", Sikuli::KeyModifier.CTRL)
end

Then /^I see the Unsafe Browser stop notification$/ do
  next if @skip_steps_while_restoring_background
  notification_helper('UnsafeBrowserStopNotification.png', 20)
  @screen.waitVanish('UnsafeBrowserStopNotification.png', 10)
end

Then /^I can start the Unsafe Browser again$/ do
  next if @skip_steps_while_restoring_background
  step "I start the Unsafe Browser"
end

Then /^I cannot configure the Unsafe Browser to use any local proxies$/ do
  next if @skip_steps_while_restoring_background
  socks_proxy = 'c' # Alt+c for socks proxy
  no_proxy    = 'y' # Alt+y for no proxy
  proxies = [[no_proxy, nil, nil]]
  socksport_lines =
    @vm.execute_successfully('grep -w "^SocksPort" /etc/tor/torrc').stdout
  assert(socksport_lines.size >= 4, "We got fewer than four Tor SocksPorts")
  socksports = socksport_lines.scan(/^SocksPort\s([^:]+):(\d+)/)
  proxies += socksports.map { |host, port| [socks_proxy, host, port] }

  proxies.each do |proxy_type, proxy_host, proxy_port|
    @screen.hide_cursor

    # Open proxy settings and select manual proxy configuration
    @screen.click('UnsafeBrowserMenuButton.png')
    @screen.wait_and_click('UnsafeBrowserPreferencesButton.png', 10)
    @screen.wait_and_click('UnsafeBrowserAdvancedSettingsButton.png', 10)
    hit, _ = @screen.waitAny(['UnsafeBrowserNetworkTabAlreadySelected.png',
                              'UnsafeBrowserNetworkTab.png'], 10)
    @screen.click(hit) if hit == 'UnsafeBrowserNetworkTab.png'
    @screen.wait_and_click('UnsafeBrowserNetworkTabSettingsButton.png', 10)
    @screen.wait_for_gnome_window('UnsafeBrowserPreferencesWindow.png', 10)
    @screen.type("m", Sikuli::KeyModifier.ALT)

    # Configure the proxy
    @screen.type(proxy_type, Sikuli::KeyModifier.ALT)  # Select correct proxy type
    @screen.type(proxy_host + Sikuli::Key.TAB + proxy_port) if proxy_type != no_proxy

    # Close settings
    @screen.type(Sikuli::Key.ENTER)
    @screen.waitVanish('UnsafeBrowserProxySettingsWindow.png', 10)

    # Test that the proxy settings work as they should
    step "I open the address \"https://check.torproject.org\" in the Unsafe Browser"
    if proxy_type == no_proxy
      @screen.wait('UnsafeBrowserTorCheckFail.png', 60)
    else
      @screen.wait('UnsafeBrowserProxyRefused.png', 60)
    end
  end
end

Then /^the Unsafe Browser has no proxy configured$/ do
  next if @skip_steps_while_restoring_background
  @screen.click('UnsafeBrowserMenuButton.png')
  @screen.wait_and_click('UnsafeBrowserPreferencesButton.png', 10)
  @screen.wait_and_click('UnsafeBrowserAdvancedSettingsButton.png', 10)
  @screen.wait_and_click('UnsafeBrowserNetworkTab.png', 10)
  @screen.wait_and_click('UnsafeBrowserNetworkTabSettingsButton.png', 10)
  @screen.wait('UnsafeBrowserProxySettingsWindow.png', 10)
  @screen.wait('UnsafeBrowserNoProxySelected.png', 10)
  @screen.type(Sikuli::Key.F4, Sikuli::KeyModifier.ALT)
  @screen.type("w", Sikuli::KeyModifier.CTRL)
end

Then /^the Unsafe Browser complains that no DNS server is configured$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserDNSError.png", 30)
end

Then /^I configure the Unsafe Browser to check for updates more frequently$/ do
  next if @skip_steps_while_restoring_background
  prefs = '/usr/share/tails/unsafe-browser/prefs.js'
  @vm.file_append(prefs, 'pref("app.update.idletime", 1);')
  @vm.file_append(prefs, 'pref("app.update.promptWaitTime", 1);')
  @vm.file_append(prefs, 'pref("app.update.interval", 5);')
end

But /^checking for updates is disabled in the Unsafe Browser's configuration$/ do
  next if @skip_steps_while_restoring_background
  prefs = '/usr/share/tails/unsafe-browser/prefs.js'
  assert(@vm.file_content(prefs).include?('pref("app.update.enabled", false)'))
end

Then /^the clearnet user has (|not )sent packets out to the Internet$/ do |sent|
  next if @skip_steps_while_restoring_background
  pkts = 0
  uid = @vm.execute_successfully("id -u clearnet").stdout.chomp.to_i
  iptables_output = @vm.execute_successfully("iptables -vnL").stdout.chomp
  output_chain = iptables_parse(iptables_output)["OUTPUT"]
  output_chain["rules"].each do |rule|
    if /owner UID match \b#{uid}\b/.match(rule["extra"])
      pkts += rule["pkts"]
    end
  end

  case sent
  when ''
    assert(pkts > 0, "Packets have not gone out to the internet.")
  when 'not'
    assert_equal(pkts, 0, "Packets have gone out to the internet.")
  end
end
