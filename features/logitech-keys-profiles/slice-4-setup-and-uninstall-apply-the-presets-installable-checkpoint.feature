Feature: Setup and uninstall put the presets' rules in place with consent and take them away again

  Scenario: Setup for the POP shows the plan, asks, then applies in a safe order
    # Still passes if: the plan lists the keys in another order
    # test: tests/test_setup.sh::pop_setup
    Given the sandbox with a running Solaar stand-in that has saved the POP Icon Keys
    When setup runs and the answer is y
    Then the plan shows the keyboard, its keys and commands, the file changes and the Solaar stop and restart notice before the prompt
    And the rules and helper are written, then Solaar is stopped, the diversion is written to its config, the Lock binding and the Solaar autostart are added in marked blocks and Solaar is restarted
    And a second run changes nothing and makes no backup

  Scenario Outline: Consent is required and dry runs write nothing
    # Still passes if: the prompt wording changes
    # test: tests/test_setup.sh::consent
    Given <situation>
    When setup runs
    Then <outcome>

    Examples:
      | situation                | outcome                                              |
      | the answer is n or empty | nothing changes and the exit is 0                    |
      | --dry-run                | diffs are shown and no file or backup is written     |
      | --yes                    | the plan is accepted and no package is installed     |
      | Solaar is not installed and --yes | it stops and says to install Solaar         |
      | damaged marker lines     | it aborts before any change                          |

  Scenario: Each keyboard's keys run its own commands, even a shared key name
    # Still passes if: a third keyboard is added
    # test: tests/test_setup.sh::two_keyboards, tests/test_rules.py::device_condition
    Given Solaar has saved the POP Icon Keys and a synthetic preset sharing a key name with it
    When setup runs
    Then each rule carries a Device condition over its own preset's names and no Model condition
    And Solaar's own evaluator fires only the rule of the keyboard that sent the key (dev machine)

  Scenario Outline: Preset text is escaped into YAML, Lua and shell text
    # Still passes if: a harmless argument is added
    # test: tests/test_rules.py::escaping
    Given a command argument holding <text>
    When the rules and the Lock binding are generated
    Then the YAML parses back to the same argument and the Lua binding is one string with the same shell words

    Examples:
      | text                                                    |
      | spaces, commas and square brackets                      |
      | a double quote and a backslash                          |
      | a hash and a colon                                      |
      | the closing long-string brackets ]] and a single quote  |

  Scenario Outline: A fresh install lists the supported keyboards and applies what Solaar then records
    # Still passes if: a third preset is added
    # test: tests/test_setup.sh::fresh_install
    Given Solaar has no entry for a supported keyboard and <later>
    When setup runs and the answer is y
    Then <outcome>

    Examples:
      | later                                        | outcome                                                                           |
      | Solaar records the POP after it is started once | the plan listed the supported keyboards and then the POP preset is applied         |
      | Solaar still records no supported keyboard      | exit 2, the supported keyboards and next steps are named, no rules block or binding |
      | declining                                    | exit 0 and no change                                                              |

  Scenario Outline: The OS mode is read-only and a mismatch only warns
    # Still passes if: the warning text changes
    # test: tests/test_setup.sh::os_mode
    Given the keyboard's Set OS is <mode>
    When setup runs
    Then <outcome>

    Examples:
      | mode                  | outcome                                                                            |
      | MacOS                 | no warning                                                                          |
      | Linux                 | the Warnings group names the keyboard, the expected MacOS and where to change it; setup continues; the mode is never changed |
      | not readable          | no warning                                                                          |

  Scenario Outline: Solaar is restarted on every way setup can end
    # Still passes if: the sleep length changes
    # test: tests/test_setup.sh::restart_guarantee
    Given setup has stopped Solaar and then <event>
    When setup ends
    Then Solaar is running again and a failure after the first change names the backups

    Examples:
      | event                                   |
      | the config write fails                  |
      | the terminal sends hangup               |
      | Ctrl-C is pressed                       |
      | Solaar does not stop in time            |

  Scenario: Other rules on handled keys are warned about, not edited
    # Still passes if: the user's rule is for a key no preset handles
    # test: tests/test_rules.py::classify_other, tests/test_setup.sh::other_rules
    Given rules.yaml holds a rule of the user's for a handled key that can fire on a handled keyboard, and one whose Device names another keyboard
    When setup runs
    Then the first is listed under Warnings as one that will also run, the second is not, and both are left untouched

  Scenario: A v0.3 install is cleaned up with consent
    # Still passes if: the old helper file has other content
    # test: tests/test_setup.sh::v03_cleanup
    Given pop-icon-keys marked blocks in rules.yaml and the Lua files, the old helper in the home bin folder and the old plugin folder present
    When setup runs and the answer is y
    Then the plan lists the old blocks and the old helper, they are removed, the logitech-keys blocks take their place with one copy of each rule and user rules are intact
    And the Warnings group says the old plugin is still installed and a second run changes nothing

  Scenario: Uninstall removes both generations and resets the known presets' ids
    # Still passes if: Solaar restarts a second later
    # test: tests/test_setup.sh::uninstall
    Given an installed POP setup, v0.3 blocks and a user diverted key on the same control id
    When uninstall runs and the answer is y
    Then the plan lists the control ids it will reset and says a key the user diverted on the same id is reset too
    And both generations' blocks and the helpers are removed, the ids are Regular in Solaar's config written while Solaar was stopped, Solaar is restarted only if uninstall stopped it, other keys, other keyboards and user rules are untouched
    And a preset with no saved entry is a no-op and dry run writes nothing

  Scenario: The v0.3 safety checks are kept
    # Still passes if: a new check is added
    # test: tests/test_setup.sh::inventory
    Given the v0.3 test inventory
    When the shell suite and the moved Python checks run
    Then every v0.3 check is kept, adapted or moved with a reason and the total is at least 119
