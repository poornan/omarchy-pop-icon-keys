Feature: The battery figure comes from the keyboard's own reports

  Scenario Outline: The helper accepts only a known slug and a percentage from 0 to 100
    # Still passes if: the error message wording changes
    # test: tests/test_battery.py::helper_validation
    Given the helper is run with <arguments>
    Then it exits <exit> and <file>

    Examples:
      | arguments                          | exit     | file                                 |
      | pop-icon-keys 0                    | 0        | writes the state file for that slug  |
      | pop-icon-keys 10                   | 0        | writes the state file for that slug  |
      | pop-icon-keys 15                   | 0        | writes the state file for that slug  |
      | pop-icon-keys 100                  | 0        | writes the state file for that slug  |
      | mx-keys-mac 95                     | 0        | writes the state file for that slug  |
      | no-such-keyboard 10                | non-zero | writes no file                       |
      | pop-icon-keys ten                  | non-zero | writes no file                       |
      | pop-icon-keys -1                   | non-zero | writes no file                       |
      | pop-icon-keys 101                  | non-zero | writes no file                       |
      | pop-icon-keys 100 with a trailing space | non-zero | writes no file                  |
      | pop-icon-keys 10.5                 | non-zero | writes no file                       |
      | pop-icon-keys                      | non-zero | writes no file                       |
      | pop-icon-keys 10 extra             | non-zero | writes no file                       |
      | ../etc 10                          | non-zero | writes no file                       |

  Scenario Outline: The state file is written atomically under the state home and never under tmp
    # Still passes if: the epoch time differs
    # test: tests/test_battery.py::helper_state_file
    Given XDG_STATE_HOME is <xdg>
    When the helper writes a report for the POP Icon Keys
    Then the file is <where> with the bucket lower bound on the first line and the epoch integer on the second, and no temporary file is left

    Examples:
      | xdg                | where                                                    |
      | set to a folder    | under that folder at logitech-keys/battery/pop-icon-keys |
      | unset              | under the home folder's .local/state                     |
      | a relative path    | under the home folder's .local/state                     |

  Scenario Outline: The helper snaps a percent to its bucket lower bound and writes exactly two lines
    # Still passes if: the epoch value differs
    # test: tests/test_battery.py::helper_state_file_content
    Given the helper is run for the POP Icon Keys with <percent> and the clock is fixed at epoch 1700000000
    Then the state file holds exactly the bytes <bytes>

    Examples:
      | percent | bytes                    |
      | 0       | 0, newline, 1700000000, newline    |
      | 9       | 0, newline, 1700000000, newline    |
      | 10      | 10, newline, 1700000000, newline   |
      | 15      | 10, newline, 1700000000, newline   |
      | 90      | 90, newline, 1700000000, newline   |
      | 95      | 90, newline, 1700000000, newline   |
      | 100     | 90, newline, 1700000000, newline   |

  Scenario: A report the helper wrote reads back through the status code
    # Still passes if: the epoch value differs
    # test: tests/test_battery.py::helper_status_round_trip
    Given the helper wrote bucket 10 for the POP Icon Keys at epoch 1700000000
    When statuscontract.battery_for reads that file with no query
    Then the battery is value 15, source report, at 1700000000
    And with a query of 100 it is still value 15, source report (the owner's case)

  Scenario: The helper never writes under tmp
    # Still passes if: the sandbox folder name differs
    # test: tests/test_battery.py::helper_no_tmp
    Given a sandbox where the temporary folder is watched
    When the helper writes a report
    Then nothing is created under the temporary folder

  Scenario: A slug list comes from the profile reader
    # Still passes if: a profile's label changes
    # test: tests/test_battery.py::helper_slugs_from_reader
    Given a temporary profiles folder with a third profile
    When the helper is run for the third profile's slug
    Then it accepts it, and a slug no profile defines is refused

  Scenario Outline: Ten bucket rules are generated for a profile with a battery feature
    # Still passes if: the comment lines above the rules change
    # test: tests/test_battery.py::rules_shape
    Given the <profile> profile
    When its rules are generated
    Then there are ten battery rules, one per bucket from 0 to 9 up to 90 to 100
    And each has a Device condition over the profile's names, the Feature <feature>, Report 0 and TestBytes 0, 1, the bucket's low and high, and executes the helper with the slug and the bucket's low

    Examples:
      | profile         | feature          |
      | POP Icon Keys   | UNIFIED BATTERY  |
      | MX Keys for Mac | BATTERY STATUS   |

  Scenario: A profile with no battery feature gets no battery rule
    # Still passes if: the key rules' order changes
    # test: tests/test_battery.py::no_battery_field_no_rules
    Given a temporary profile with no battery field
    When its rules are generated
    Then it has its key rules and no battery rule

  Scenario Outline: Solaar's own rule code fires only the right bucket for only that keyboard
    # Still passes if: the notification carries other bytes after byte 0
    # test: tests/test_battery.py::solaar_evaluates_battery_rules
    Given the generated rules loaded by Solaar's own loader and a notification of <feature> from <device> with byte 0 equal to <byte>
    When Solaar's own evaluator checks every battery rule
    Then only the <bucket> rule of <owner> fires
    And on CI, where Solaar is not installed, the check is skipped with a printed note, and on the development machine with LK_REQUIRE_SOLAAR=1 a skip is a failure

    Examples:
      | feature          | device          | byte | bucket    | owner           |
      | UNIFIED BATTERY  | POP Icon Keys   | 15   | 10 to 19  | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 0    | 0 to 9    | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 100  | 90 to 100 | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 9    | 0 to 9    | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 10   | 10 to 19  | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 19   | 10 to 19  | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 20   | 20 to 29  | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 89   | 80 to 89  | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 90   | 90 to 100 | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 99   | 90 to 100 | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 101  | none      | none (a byte above 100 fires nothing) |
      | BATTERY STATUS   | MX Keys for Mac | 15   | 10 to 19  | MX Keys for Mac |
      | UNIFIED BATTERY  | MX Keys for Mac | 15   | none      | none (the feature belongs to the POP rules and the device does not match) |
      | BATTERY STATUS   | POP Icon Keys   | 15   | none      | none            |

  Scenario Outline: Battery rules are ours, are not duplicated and are not overlaps
    # Still passes if: Solaar's editor reorders the rules
    # test: tests/test_battery.py::classify_and_idempotent
    Given a rules file with the generated battery rules <shape>
    When the rules are classified and generated again
    Then every battery rule is kind plugin with no overlap and the second generation changes nothing

    Examples:
      | shape                                              |
      | inside the marked block                            |
      | rewritten by Solaar's editor without markers       |
      | in CRLF line endings                               |

  Scenario: Applying then removing a profile with battery rules leaves the files as they were
    # Still passes if: Solaar's editor reorders the rules
    # test: tests/test_battery.py::apply_remove_round_trip
    Given a sandbox rules file and the POP Icon Keys profile, which has a battery feature
    When its rules block is put and then dropped through the rules and fileedit modules
    Then the rules file is byte-identical to before
    And every battery rule that was put is classified as ours (kind plugin, no overlap) before it is dropped

  Scenario Outline: Removing the state directory takes the plugin's folder and nothing else
    # Still passes if: the battery folder is empty
    # test: tests/test_battery.py::remove_state
    Given a state home with the logitech-keys folder holding applied.json and battery files, and another folder beside it
    When remove-state runs <mode> through lib/battery.py, which delegates to lib/statedir.py
    Then <result>

    Examples:
      | mode        | result                                                                       |
      | for real    | the logitech-keys folder is gone and the other folder is byte-identical      |
      | as a dry run| nothing is removed and the folder it would remove is printed                 |
      | when there is no folder | it exits 0 and changes nothing                                   |
