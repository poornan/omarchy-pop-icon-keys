Feature: The battery comes from the keyboard's own reports, kept with their age

  Scenario Outline: Ten bucket rules turn a battery notification into a bucket
    # Still passes if: the helper path in the rule differs
    # test: tests/test_rules.py::battery_buckets
    Given the POP preset with feature UNIFIED BATTERY and a notification with byte 0 equal to <percent>
    When Solaar's own evaluator runs the generated rules
    Then only the rule for bucket <bucket> fires, for only that keyboard

    Examples:
      | percent | bucket |
      | 0       | 0      |
      | 15      | 10     |
      | 99      | 90     |
      | 100     | 90     |

  Scenario: The MX uses BATTERY STATUS and a preset without a battery gets no rules
    # Still passes if: the key rules change
    # test: tests/test_rules.py::battery_features
    Given the MX preset with feature BATTERY STATUS and a synthetic preset without a battery field
    When rules are generated and classified
    Then the MX gets ten rules matching its own notification, the other gets none and every battery rule is ours with no overlap
    And running setup again changes nothing and uninstall removes them

  Scenario Outline: The helper validates and snaps its input
    # Still passes if: the epoch value differs
    # test: tests/test_battery.py::helper_matrix
    Given the helper is run with <slug> and <percent>
    When it finishes
    Then <outcome>

    Examples:
      | slug          | percent | outcome                                                  |
      | pop-icon-keys | 15      | the file holds 10 then the epoch, written atomically     |
      | pop-icon-keys | 0, 95, 100 | the files hold 0, 90 and 90                           |
      | ../x          | 15      | non-zero exit and nothing written anywhere               |
      | Pop           | 15      | non-zero exit and nothing written                        |
      | pop-icon-keys | 101, -1, abc, 1.5 | non-zero exit and nothing written              |
      | no argument or three arguments | -  | non-zero exit and nothing written                 |

  Scenario: The helper's report reads back as the status battery and only the helper writes
    # Still passes if: the state folder is under a different XDG path
    # test: tests/test_battery.py::round_trip
    Given an unset or relative XDG_STATE_HOME and the helper run with bucket 10
    When status is built
    Then the battery is value 15 with source report, the file lives under the default state folder and never under /tmp
    And a source check finds no other writer of that folder

  Scenario: Setup installs the helper and uninstall removes it and the state directory
    # Still passes if: the state directory holds no files
    # test: tests/test_setup.sh::battery_install
    Given a setup with battery rules and a battery state file
    When uninstall runs
    Then the helper copy and the whole state directory are removed, the plan lists them, a dry run removes nothing and no other file is touched
