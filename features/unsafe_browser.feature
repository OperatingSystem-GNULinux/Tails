@product
Feature: Browsing the web using the Unsafe Browser
  As a Tails user
  when I browse the web using the Unsafe Browser
  I should have direct access to the web

  @fragile
  Scenario: The Unsafe Browser can access the LAN
    Given I have started Tails from DVD and logged in and the network is connected
    And a web server is running on the LAN
    When I successfully start the Unsafe Browser
    And I open a page on the LAN web server in the Unsafe Browser
    Then I see "UnsafeBrowserHelloLANWebServer.png" after at most 20 seconds

  @fragile
  Scenario: Starting the Unsafe Browser works as it should.
    Given I have started Tails from DVD and logged in and the network is connected
    When I successfully start the Unsafe Browser
    Then the Unsafe Browser runs as the expected user
    And the Unsafe Browser has a red theme
    And the Unsafe Browser shows a warning as its start page
    And the Unsafe Browser has no plugins installed
    And the Unsafe Browser has no add-ons installed
    And the Unsafe Browser has only Firefox's default bookmarks configured
    And the Unsafe Browser has no proxy configured
    And the Unsafe Browser uses all expected TBB shared libraries

  @fragile
  Scenario: Closing the Unsafe Browser shows a stop notification and properly tears down the chroot.
    Given I have started Tails from DVD and logged in and the network is connected
    When I successfully start the Unsafe Browser
    And I close the Unsafe Browser
    Then I see the Unsafe Browser stop notification
    And the Unsafe Browser chroot is torn down

  @fragile
  Scenario: Starting a second instance of the Unsafe Browser results in an error message being shown.
    Given I have started Tails from DVD and logged in and the network is connected
    When I successfully start the Unsafe Browser
    And I start the Unsafe Browser
    Then I see a warning about another instance already running

  @fragile
  Scenario: Opening check.torproject.org in the Unsafe Browser shows the red onion and a warning message.
    Given I have started Tails from DVD and logged in and the network is connected
    When I successfully start the Unsafe Browser
    And I open the address "https://check.torproject.org" in the Unsafe Browser
    Then I see "UnsafeBrowserTorCheckFail.png" after at most 60 seconds
    And the clearnet user has sent packets out to the Internet

  @fragile
  Scenario: The Unsafe Browser cannot be configured to use Tor and other local proxies.
    Given I have started Tails from DVD and logged in and the network is connected
    When I successfully start the Unsafe Browser
    Then I cannot configure the Unsafe Browser to use any local proxies

  @fragile
  Scenario: The Unsafe Browser will not make any connections to the Internet which are not user initiated
    Given I have started Tails from DVD and logged in and the network is connected
    And I capture all network traffic
    And Tor is ready
    And I configure the Unsafe Browser to check for updates more frequently
    But checking for updates is disabled in the Unsafe Browser's configuration
    When I successfully start the Unsafe Browser
    Then the Unsafe Browser has started
    And I wait 120 seconds
    And the clearnet user has not sent packets out to the Internet
    And all Internet traffic has only flowed through Tor

  Scenario: Starting the Unsafe Browser without a network connection results in a complaint about no DNS server being configured
    Given I have started Tails from DVD without network and logged in
    When I start the Unsafe Browser
    Then the Unsafe Browser complains that no DNS server is configured
