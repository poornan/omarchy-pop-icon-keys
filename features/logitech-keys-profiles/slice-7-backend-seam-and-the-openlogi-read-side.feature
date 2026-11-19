Feature: Backends sit behind one seam and OpenLogi is read-only

  Scenario: The registry and each backend carry the whole contract
    # Still passes if: a backend's label text changes
    # test: tests/test_backend_contract.py::registry_and_contract
    Given the backend registry
    Then it names exactly solaar and openlogi
    And each backend module has NAME, LABEL, EXPERIMENTAL, LIVE_KEY_STATE, collect, probe, known, keyboards, restore, plan_apply and plan_remove
    And each backend's shell file defines installed, running, stop, start and restart_if_stopped under its own prefix
    And Solaar has EXPERIMENTAL false and LIVE_KEY_STATE true while OpenLogi has EXPERIMENTAL true and LIVE_KEY_STATE false

  Scenario: An unknown backend name is refused
    # Still passes if: the refusal text changes
    # test: tests/test_backend_contract.py::unknown_backend
    Given the edit command is given --backend vendor
    Then it exits non-zero naming the two known backends and changes nothing

  Scenario: The Solaar adapter gives the same status and restore as before the seam
    # Still passes if: the battery percentage differs
    # test: tests/test_backend_contract.py::solaar_adapter_equals_status
    Given the recorded POP Icon Keys and MX Keys for Mac fixtures and the derived routed, dropped and not-set-up variants
    When the status is built through the Solaar adapter and directly by Slice 2's builder
    Then the two JSON documents are identical
    And the restore argv list equals the restore-plan commands of Slice 2 for each dropped key

  Scenario: Only collect does any I/O
    # Still passes if: collect gains another read-only command
    # test: tests/test_backend_contract.py::pure_outside_collect
    Given each backend module with files, processes and the clock made to fail
    When probe, known, keyboards, restore, plan_apply and plan_remove run on raw data
    Then none of them raises for I/O and collect alone uses the injected run function and the injected paths

  Scenario Outline: Collect may run only its read-only commands
    # Still passes if: the order of the allowed commands changes
    # test: tests/test_backend_contract.py::collect_allow_list
    Given the <backend> backend's collect with a recording run function
    When it collects
    Then every argv it passed is in the allow-list <allowed>

    Examples:
      | backend  | allowed                                                      |
      | solaar   | solaar show "<selector>" for the shipped profiles' exact names and the saved-entry names matched by model id, one call per selector, never solaar show all |
      | solaar   | the same with a third profile that has its own exact name     |
      | openlogi | openlogi api status and openlogi api devices                 |

  Scenario Outline: OpenLogi keyboards are matched by exact name only
    # Still passes if: the device's battery level differs
    # test: tests/test_backend_contract.py::openlogi_identity
    Given the OpenLogi inventory has a device named <name> and the profile has <profile names>
    When the devices are matched
    Then the result is <result>

    Examples:
      | name                    | profile names                                   | result                                          |
      | POP Icon Keys           | names POP Icon Keys                             | matched                                         |
      | POP Icon Keys Mini      | names POP Icon Keys                             | no match                                        |
      | pop icon keys           | names POP Icon Keys                             | no match                                        |
      | POP Icon Keys (2)       | names POP Icon Keys                             | no match                                        |
      | the name is null        | names POP Icon Keys                             | no match                                        |
      | MX Keys S               | names MX Keys for Mac                           | no match                                        |
      | MX Keys for Mac Plus    | names MX Keys for Mac                           | no match                                        |
      | Logi MX Keys Mac        | backends.openlogi.names Logi MX Keys Mac        | matched through the openlogi names              |
      | two devices both named POP Icon Keys | names POP Icon Keys                | both marked ambiguous and not restored          |

  Scenario: The Solaar adapter's collect survives a crashing show call
    # Still passes if: the crashing call is the first or the last
    # test: tests/test_backend_contract.py::solaar_collect_crash
    Given the Solaar backend's collect with a run function whose call for the MX Keys for Mac crashes with the UnicodeDecodeError text and whose call for the POP Icon Keys succeeds
    When the status is built through the Solaar adapter
    Then the POP Icon Keys section has its states, the MX Keys for Mac section has every key unknown and readProblem solaarCrashed, and the JSON passes validate_status
    And the result equals Slice 2's builder for the same raw outputs

  Scenario: A ready OpenLogi inventory gives keyboard sections with the backend's battery
    # Still passes if: the second keyboard's battery level differs
    # test: tests/test_backend_contract.py::openlogi_sections
    Given the synthetic ready devices envelope with an online POP Icon Keys, an offline MX Keys for Mac and a mouse
    When the status is built through the OpenLogi backend
    Then there is one section, for the online POP Icon Keys, marked tested
    And its battery has the percentage as value, the level as given or null, source backend and the read time
    And the backend block says experimental true, usable true, liveKeyState false and installed and running from the lifecycle
    And the offline keyboard and the mouse have no section

  Scenario Outline: An unusable OpenLogi becomes a problem code, never a crash
    # Still passes if: the error message text inside the envelope changes
    # test: tests/test_backend_contract.py::openlogi_problems
    Given the OpenLogi command outputs <output>
    When the backend is probed and the status is built
    Then usable is false and the problem is <problem> and the status is valid JSON with no keyboards

    Examples:
      | output                                                              | problem           |
      | ok false with code agent_unavailable                                | agentUnavailable  |
      | ok false with code version_mismatch and exit status 1               | versionMismatch   |
      | ok true with inventory scanning                                     | inventoryNotReady |
      | ok true with inventory unavailable                                 | inventoryNotReady |
      | schema_version 2                                                    | unknownSchema     |
      | text that is not JSON                                               | unknownSchema     |
      | exit status 2 and no output                                         | unknownSchema     |
      | an empty ready inventory                                            | none, usable true, no keyboards |

  Scenario: Every OpenLogi key is unsupported by the backend and nothing is restorable
    # Still passes if: the key labels change
    # test: tests/test_backend_contract.py::openlogi_keys_unsupported
    Given a matched POP Icon Keys under the OpenLogi backend
    When the sections and the restore list are built
    Then every key has state unsupportedByBackend with reason notImplemented and none is routed, dropped or notSetUp
    And the status passes the contract check and restore returns an empty list
    And plan_apply returns no OpenLogi edit and every key outcome is unsupported

  Scenario Outline: Both backends obey the same properties
    # Still passes if: the profile's key labels change
    # test: tests/test_backend_contract.py::shared_properties
    Given the <backend> backend over the shipped profiles and its synthetic or recorded input
    Then <property>

    Examples:
      | backend  | property                                                                                         |
      | solaar   | every key state is in the enum and absent never counts toward the warning                        |
      | openlogi | every key state is in the enum and unsupportedByBackend never counts toward the warning          |
      | solaar   | restore returns only allow-listed argv and writes no file                                        |
      | openlogi | restore returns only allow-listed argv and writes no file                                        |
      | solaar   | plan_apply touches only the paths it declares and a second plan_apply changes nothing            |
      | openlogi | plan_apply touches only the paths it declares and a second plan_apply changes nothing            |
      | solaar   | plan_remove after plan_apply leaves every file byte-identical to before                          |
      | openlogi | plan_remove after plan_apply leaves every file byte-identical to before                          |
      | solaar   | a look-alike name does not match and an ambiguous name is skipped for restore                    |
      | openlogi | a look-alike name does not match and an ambiguous name is skipped for restore                    |

  Scenario: The Hyprland bindings block applies under either backend
    # Still passes if: the Lua comment text changes
    # test: tests/test_backend_contract.py::bindings_backend_neutral
    Given the POP Icon Keys is matched under the OpenLogi backend
    When the common plan is computed
    Then it has the marked bindings block with SUPER + CTRL + Q running the lock action
    And the OpenLogi backend itself adds no edit

  Scenario: OpenLogi's configuration and unit folder are never written
    # Still passes if: the sandbox folder name differs
    # test: tests/test_backend_contract.py::openlogi_never_written
    Given a sandbox home with an OpenLogi config.toml and a systemd user folder, both checksummed
    When status, restore, plan_apply and plan_remove run under the OpenLogi backend
    Then both checksums are unchanged and the systemctl stub log shows no command at all

  Scenario Outline: The lifecycle functions detect and run the right daemon
    # Still passes if: the stub logs extra environment lines
    # test: tests/test_backend_contract.py::lifecycle_functions
    Given the stubs report <state>
    When the lifecycle functions of the OpenLogi and Solaar backends run in a dry run and for real
    Then <result>

    Examples:
      | state                                                             | result                                                                     |
      | openlogi on PATH and its unit file present                        | openlogi_installed succeeds                                                |
      | openlogi on PATH and no unit file                                 | openlogi_installed fails                                                   |
      | only a Flatpak openlogi                                           | openlogi_installed fails                                                   |
      | the unit is active                                                | openlogi_running succeeds                                                  |
      | the unit is inactive but an openlogi-agent process of this user exists | openlogi_running succeeds                                             |
      | neither                                                           | openlogi_running fails                                                     |
      | stop then restart_if_stopped on a stopped agent                   | the stub log shows stop then start for that unit only                      |
      | restart_if_stopped when this code did not stop it                 | nothing is started                                                         |
      | a dry run of stop and start                                       | the stub log is empty                                                      |
      | a systemctl call for any other unit or without --user             | the stub refuses it and the test fails                                     |

  Scenario Outline: The status helper reports the other backend that also runs
    # Still passes if: the helper takes a little longer to run
    # test: tests/test_backend_contract.py::other_running
    Given Solaar is <solaar> and OpenLogi's agent is <openlogi>
    When the status helper runs for the active backend <active>
    Then it exits 0 with valid JSON whose otherRunning is <other>

    Examples:
      | solaar  | openlogi | active   | other    |
      | running | stopped  | solaar   | null     |
      | running | running  | solaar   | openlogi |
      | running | running  | openlogi | solaar   |
      | stopped | running  | openlogi | null     |

  Scenario: The stubs and fixtures are labelled synthetic and a missing stub fails the run
    # Still passes if: a fixture gains another device
    # test: tests/test_backend_contract.py::synthetic_labels_and_stub_guard
    Given the OpenLogi fixtures and stubs
    Then each carries the label "synthetic: doc-derived USAGE.md @9ca7ef0"
    And a run with the openlogi or systemctl stub missing from PATH fails before any test runs
    And no profile has a backends.openlogi.verified block
