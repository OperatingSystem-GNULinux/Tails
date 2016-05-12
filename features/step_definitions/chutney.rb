def ensure_chutney_is_running
  # Ensure that a fresh chutney instance is running, and that it will
  # be cleaned upon exit. We only do it once, though, since the same
  # setup can be used throughout the same test suite run.
  if not($chutney_initialized)
    chutney_src_dir = "#{GIT_DIR}/submodules/chutney"
    chutney_listen_address = $vmnet.bridge_ip_addr
    chutney_script = "#{chutney_src_dir}/chutney"
    assert(
      File.executable?(chutney_script),
      "It does not look like '#{chutney_src_dir}' is the Chutney source tree"
    )
    network_definition = "#{GIT_DIR}/features/chutney/test-network"
    env = {
      'CHUTNEY_LISTEN_ADDRESS' => chutney_listen_address,
      'CHUTNEY_DATA_DIR' => "#{$config['TMPDIR']}/chutney-data/"
    }

    chutney_data_dir_cleanup = Proc.new do
      if File.directory?(env['CHUTNEY_DATA_DIR'])
        FileUtils.rm_r(env['CHUTNEY_DATA_DIR'])
      end
    end

    chutney_cmd = Proc.new do |cmd|
      Dir.chdir(chutney_src_dir) do
        cmd_helper([chutney_script, cmd, network_definition], env)
      end
    end

    if KEEP_SNAPSHOTS
      begin
        chutney_cmd.call('start')
      rescue Test::Unit::AssertionFailedError
        if File.directory?(env['CHUTNEY_DATA_DIR'])
          raise "You are running with --keep-snapshots but Chutney failed " +
                "to start with its current data directory. To recover you " +
                "likely want to delete '#{env['CHUTNEY_DATA_DIR']}' and " +
                "all test suite snapshots and then start over."
        else
          chutney_cmd.call('configure')
          chutney_cmd.call('start')
        end
      end
    else
      chutney_cmd.call('stop')
      chutney_data_dir_cleanup.call
      chutney_cmd.call('configure')
      chutney_cmd.call('start')
    end

    at_exit do
      chutney_cmd.call('stop')
      chutney_data_dir_cleanup.call unless KEEP_SNAPSHOTS
    end

    $chutney_initialized = true
  end
end

When /^I configure Tails to use a simulated Tor network$/ do
  # At the moment this step essentially assumes that we boot with 'the
  # network is unplugged', run this step, and then 'the network is
  # plugged'. I believe we can make this pretty transparent without
  # the need of a dedicated step by using tags (e.g. @fake_tor or
  # whatever -- possibly we want the opposite, @real_tor,
  # instead).
  #
  # There are two time points where we for a scenario must ensure that
  # the client configuration below is enabled if and only if the
  # scenario is tagged, and that is:
  #
  # 1. During a proper boot, as soon as the remote shell is up in the
  #    'the computer boots Tails' step.
  #
  # 2. When restoring a snapshot, in restore_background().
  #
  # If we do this, it doesn't even matter if a snapshot is made of an
  # untagged scenario (without the conf), and we later restore it with
  # a tagged scenario.
  #
  # Note: We probably have to clear the /var/lib/tor data dir when we
  # switch mode. Possibly there are other such problems that make this
  # abstraction impractical and it's better that we avoid it an go
  # with the more explicit, step-based approach.

  assert(not($vm.execute('service tor status').success?),
         "Running this step when Tor is running is probably not intentional")
  ensure_chutney_is_running
  # Most of these lines are taken from chutney's client template.
  client_torrc_lines = [
    'TestingTorNetwork 1',
    'AssumeReachable 1',
    'PathsNeededToBuildCircuits 0.25',
    'TestingBridgeDownloadSchedule 0, 5',
    'TestingClientConsensusDownloadSchedule 0, 5',
    'TestingClientDownloadSchedule 0, 5',
    'TestingDirAuthVoteExit *',
    'TestingDirAuthVoteGuard *',
    'TestingDirAuthVoteHSDir *',
    'TestingMinExitFlagThreshold 0',
    'V3AuthNIntervalsValid 2',
    # Enabling TestingTorNetwork disables ClientRejectInternalAddresses
    # so the Tor client will happily try LAN connections. Coupled with
    # that TestingTorNetwork is enabled on all exits, and their
    # ExitPolicyRejectPrivate is disabled, we will allow exiting to
    # LAN hosts. We have at least one test that tries to make sure
    # that is *not* possible (Scenario: The Tor Browser cannot access
    # the LAN) so we cannot allow it. We'll have to rethink all this
    # if we ever want to run all services locally as well (#9520).
    'ClientRejectInternalAddresses 1',
  ]
  # We run one client in chutney so we easily can grep the generated
  # DirAuthority lines and use them.
  chutney_src_dir = "#{GIT_DIR}/submodules/chutney"
  client_torrcs = Dir.glob(
    "#{$config['TMPDIR']}/chutney-data/nodes/*client/torrc"
  )
  dir_auth_lines = open(client_torrcs.first) do |f|
    f.grep(/^(Alternate)?(Dir|Bridge)Authority\s/)
  end
  client_torrc_lines.concat(dir_auth_lines)
  $vm.file_append('/etc/tor/torrc', client_torrc_lines)
end

When /^Tails is using the real Tor network$/ do
  assert($vm.execute('grep "TestingTorNetwork 1" /etc/torrc').failure?)
end
