Then /^I see the (Unsafe|I2P) Browser start notification and wait for it to close$/ do |browser_type|
  notification_popup_wait("#{browser_type}BrowserStartNotification.png", 30)
  @screen.waitVanish("#{browser_type}BrowserStartNotification.png", 10)
end

Then /^the (Unsafe|I2P) Browser has started$/ do |browser_type|
  case browser_type
  when 'Unsafe'
    @screen.wait("UnsafeBrowserHomepage.png", 360)
  when 'I2P'
    step 'the I2P router console is displayed in I2P Browser'
  end
end

When /^I start the (Unsafe|I2P) Browser(?: through the GNOME menu)?$/ do |browser_type|
  step "I start \"#{browser_type}Browser\" via the GNOME \"Internet\" applications menu"
end

When /^I successfully start the (Unsafe|I2P) Browser$/ do |browser_type|
  step "I start the #{browser_type} Browser"
  step "I see and accept the Unsafe Browser start verification" unless browser_type == 'I2P'
  step "I see the #{browser_type} Browser start notification and wait for it to close"
  step "the #{browser_type} Browser has started"
end

When /^I close the (?:Unsafe|I2P) Browser$/ do
  @screen.type("q", Sikuli::KeyModifier.CTRL)
end

Then /^I see the (Unsafe|I2P) Browser stop notification$/ do |browser_type|
  notification_popup_wait("#{browser_type}BrowserStopNotification.png", 20)
  @screen.waitVanish("#{browser_type}BrowserStopNotification.png", 10)
end

def xul_application_info(application)
  binary = $vm.execute_successfully(
    'echo ${TBB_INSTALL}/firefox', :libs => 'tor-browser'
  ).stdout.chomp
  address_bar_image = "BrowserAddressBar.png"
  case application
  when "Tor Browser"
    user = LIVE_USER
    cmd_regex = "#{binary} .* -profile /home/#{user}/\.tor-browser/profile\.default"
    chroot = ""
    new_tab_button_image = "TorBrowserNewTabButton.png"
  when "Unsafe Browser"
    user = "clearnet"
    cmd_regex = "#{binary} .* -profile /home/#{user}/\.unsafe-browser/profile\.default"
    chroot = "/var/lib/unsafe-browser/chroot"
    new_tab_button_image = "UnsafeBrowserNewTabButton.png"
  when "I2P Browser"
    user = "i2pbrowser"
    cmd_regex = "#{binary} .* -profile /home/#{user}/\.i2p-browser/profile\.default"
    chroot = "/var/lib/i2p-browser/chroot"
    new_tab_button_image = "I2PBrowserNewTabButton.png"
  when "Tor Launcher"
    user = "tor-launcher"
    cmd_regex = "#{binary} -app /home/#{user}/\.tor-launcher/tor-launcher-standalone/application\.ini"
    chroot = ""
    new_tab_button_image = nil
    address_bar_image = nil
  else
    raise "Invalid browser or XUL application: #{application}"
  end
  return {
    :user => user,
    :cmd_regex => cmd_regex,
    :chroot => chroot,
    :new_tab_button_image => new_tab_button_image,
    :address_bar_image => address_bar_image,
  }
end

When /^I open a new tab in the (.*)$/ do |browser|
  info = xul_application_info(browser)
  @screen.click(info[:new_tab_button_image])
  @screen.wait(info[:address_bar_image], 10)
end

When /^I open the address "([^"]*)" in the (.*)$/ do |address, browser|
  step "I open a new tab in the #{browser}"
  info = xul_application_info(browser)
  open_address = Proc.new do
    @screen.click(info[:address_bar_image])
    sleep 0.5
    @screen.type(address + Sikuli::Key.ENTER)
  end
  open_address.call
  if browser == "Tor Browser"
    recovery_on_failure = Proc.new do
      @screen.type(Sikuli::Key.ESC)
      @screen.waitVanish('BrowserReloadButton.png', 3)
      open_address.call
    end
    retry_tor(recovery_on_failure) do
      @screen.wait('BrowserReloadButton.png', 120)
    end
  end
end

Then /^the (.*) has no plugins installed$/ do |browser|
  step "I open the address \"about:plugins\" in the #{browser}"
  step "I see \"TorBrowserNoPlugins.png\" after at most 30 seconds"
end

def xul_app_shared_lib_check(pid, chroot)
  expected_absent_tbb_libs = ['libnssdbm3.so']
  absent_tbb_libs = []
  unwanted_native_libs = []
  tbb_libs = $vm.execute_successfully(
    "ls -1 #{chroot}${TBB_INSTALL}/*.so", :libs => 'tor-browser'
  ).stdout.split
  firefox_pmap_info = $vm.execute("pmap #{pid}").stdout
  for lib in tbb_libs do
    lib_name = File.basename lib
    if not /\W#{lib}$/.match firefox_pmap_info
      absent_tbb_libs << lib_name
    end
    native_libs = $vm.execute_successfully(
                       "find /usr/lib /lib -name \"#{lib_name}\""
                                           ).stdout.split
    for native_lib in native_libs do
      if /\W#{native_lib}$"/.match firefox_pmap_info
        unwanted_native_libs << lib_name
      end
    end
  end
  absent_tbb_libs -= expected_absent_tbb_libs
  assert(absent_tbb_libs.empty? && unwanted_native_libs.empty?,
         "The loaded shared libraries for the firefox process are not the " +
         "way we expect them.\n" +
         "Expected TBB libs that are absent: #{absent_tbb_libs}\n" +
         "Native libs that we don't want: #{unwanted_native_libs}")
end

Then /^the (.*) uses all expected TBB shared libraries$/ do |application|
  info = xul_application_info(application)
  pid = $vm.execute_successfully("pgrep --uid #{info[:user]} --full --exact '#{info[:cmd_regex]}'").stdout.chomp
  assert(/\A\d+\z/.match(pid), "It seems like #{application} is not running")
  xul_app_shared_lib_check(pid, info[:chroot])
end

Then /^the (.*) chroot is torn down$/ do |browser|
  info = xul_application_info(browser)
  try_for(30, :msg => "The #{browser} chroot '#{info[:chroot]}' was " \
                      "not removed") do
    !$vm.execute("test -d '#{info[:chroot]}'").success?
  end
end

Then /^the (.*) runs as the expected user$/ do |browser|
  info = xul_application_info(browser)
  assert_vmcommand_success($vm.execute(
    "pgrep --full --exact '#{info[:cmd_regex]}'"),
    "The #{browser} is not running")
  assert_vmcommand_success($vm.execute(
    "pgrep --uid #{info[:user]} --full --exact '#{info[:cmd_regex]}'"),
    "The #{browser} is not running as the #{info[:user]} user")
end