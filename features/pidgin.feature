@product
Feature: Chatting anonymously using Pidgin
  As a Tails user
  when I chat using Pidgin
  I should be able to use OTR
  And I should be able to persist my Pidgin configuration
  And AppArmor should prevent Pidgin from doing dangerous things
  And all Internet traffic should flow only through Tor

  @check_tor_leaks
  Scenario: Chatting with some friend over XMPP
    Given I have started Tails from DVD and logged in and the network is connected
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I create my XMPP account
    And I close Pidgin's account manager window
    Then Pidgin automatically enables my XMPP account
    Given my XMPP friend goes online
    When I start a conversation with my friend
    And I say something to my friend
    Then I receive a response from my friend

  @check_tor_leaks
  Scenario: Chatting with some friend over XMPP in a multi-user chat
    Given I have started Tails from DVD and logged in and the network is connected
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I create my XMPP account
    And I close Pidgin's account manager window
    Then Pidgin automatically enables my XMPP account
    When I join some empty multi-user chat
    And I clear the multi-user chat's scrollback
    And my XMPP friend goes online and joins the multi-user chat
    Then I can see that my friend joined the multi-user chat
    And I say something to my friend in the multi-user chat
    Then I receive a response from my friend in the multi-user chat

  @check_tor_leaks
  Scenario: Chatting with some friend over XMPP and with OTR
    Given I have started Tails from DVD and logged in and the network is connected
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I create my XMPP account
    And I close Pidgin's account manager window
    Then Pidgin automatically enables my XMPP account
    Given my XMPP friend goes online
    When I start a conversation with my friend
    And I start an OTR session with my friend
    Then Pidgin automatically generates an OTR key
    And an OTR session was successfully started with my friend
    When I say something to my friend
    Then I receive a response from my friend

  # 10375 - Increase the number of Tor circuit retries in the test suite
  # 10376 - "the Tor Browser loads the (startup page|Tails roadmap)" step is fragile
  # 10443 - OFTC tests are fragile
  @check_tor_leaks @fragile
  Scenario: Connecting to the #tails IRC channel with the pre-configured account
    Given I have started Tails from DVD and logged in and the network is connected
    And Pidgin has the expected accounts configured with random nicknames
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I activate the "irc.oftc.net" Pidgin account
    And I close Pidgin's account manager window
    Then Pidgin successfully connects to the "irc.oftc.net" account
    And I can join the "#tails" channel on "irc.oftc.net"
    When I type "/topic"
    And I press the "ENTER" key
    Then I see the Tails roadmap URL
    When I click on the Tails roadmap URL
    Then the Tor Browser has started and loaded the Tails roadmap
    And the "irc.oftc.net" account only responds to PING and VERSION CTCP requests

  Scenario: Adding a certificate to Pidgin
    Given I have started Tails from DVD and logged in and the network is connected
    And I start Pidgin through the GNOME menu
    And I see Pidgin's account manager window
    And I close Pidgin's account manager window
    Then I can add a certificate from the "/home/amnesia" directory to Pidgin

  Scenario: Failing to add a certificate to Pidgin
    Given I have started Tails from DVD and logged in and the network is connected
    When I start Pidgin through the GNOME menu
    And I see Pidgin's account manager window
    And I close Pidgin's account manager window
    Then I cannot add a certificate from the "/home/amnesia/.gnupg" directory to Pidgin
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Then I cannot add a certificate from the "/lib/live/mount/overlay/home/amnesia/.gnupg" directory to Pidgin
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Then I cannot add a certificate from the "/live/overlay/home/amnesia/.gnupg" directory to Pidgin

  @check_tor_leaks @fragile
  Scenario: Using a persistent Pidgin configuration
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And Pidgin has the expected accounts configured with random nicknames
    And the network is plugged
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    # And I generate an OTR key for the default Pidgin account
    And I take note of the configured Pidgin accounts
    # And I take note of the OTR key for Pidgin's "irc.oftc.net" account
    And I shutdown Tails and wait for the computer to power off
    Given a computer
    And I start Tails from USB drive "current" and I login with persistence enabled
    And Pidgin has the expected persistent accounts configured
    # And Pidgin has the expected persistent OTR keys
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I activate the "irc.oftc.net" Pidgin account
    And I close Pidgin's account manager window
    Then Pidgin successfully connects to the "irc.oftc.net" account
    And I can join the "#tails" channel on "irc.oftc.net"
    # Exercise Pidgin AppArmor profile with persistence enabled.
    # This should really be in dedicated scenarios, but it would be
    # too costly to set up the virtual USB drive with persistence more
    # than once in this feature.
    Given I start monitoring the AppArmor log of "/usr/bin/pidgin"
    Then I cannot add a certificate from the "/home/amnesia/.gnupg" directory to Pidgin
    And AppArmor has denied "/usr/bin/pidgin" from opening "/home/amnesia/.gnupg/test.crt"
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Given I restart monitoring the AppArmor log of "/usr/bin/pidgin"
    Then I cannot add a certificate from the "/live/persistence/TailsData_unlocked/gnupg" directory to Pidgin
    And AppArmor has denied "/usr/bin/pidgin" from opening "/live/persistence/TailsData_unlocked/gnupg/test.crt"
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Then I can add a certificate from the "/home/amnesia" directory to Pidgin
