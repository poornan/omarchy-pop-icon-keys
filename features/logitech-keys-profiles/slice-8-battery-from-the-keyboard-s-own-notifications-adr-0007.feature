Feature: The battery figure comes from the keyboard's own reports

  Scenario Outline: The helper accepts only a known slug and a percentage from 0 to 100
    # Still passes if: the error message wording changes
    # test: tests/test_battery.py::helper_validation
    Given the helper is run with <arguments>
    Then it exits <exit> and <file>

    Examples:
      | arguments                          | exit     | file                                 |
      | pop-icon-keys 10                   | 0        | writes the state file for that slug  |
      | mx-keys-mac 95                     | 0        | writes the state file for that slug  |
      | no-such-keyboard 10                | non-zero | writes no file                       |
      | pop-icon-keys ten                  | non-zero | writes no file                       |
      | pop-icon-keys -1                   | non-zero | writes no file                       |
      | pop-icon-keys 101                  | non-zero | writes no file                       |
      | pop-icon-keys 10.5                 | non-zero | writes no file                       |
      | pop-icon-keys                      | non-zero | writes no file                       |
      | pop-icon-keys 10 extra             | non-zero | writes no file                       |
      | ../etc 10                          | non-zero | writes no file                       |

  Scenario Outline: The state file is written atomically under the state home and never under tmp
    # Still passes if: the epoch time differs
    # test: tests/test_battery.py::helper_state_file
    Given XDG_STATE_HOME is <xdg>
    When the helper writes a report for the POP Icon Keys
    Then the file is <where> with the bucket lower bound and the epoch time on two lines and no temporary file is left

    Examples:
      | xdg                | where                                                    |
      | set to a folder    | under that folder at logitech-keys/battery/pop-icon-keys |
      | unset              | under the home folder's .local/state                     |
      | a relative path    | under the home folder's .local/state                     |

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

    Examples:
      | feature          | device          | byte | bucket    | owner           |
      | UNIFIED BATTERY  | POP Icon Keys   | 15   | 10 to 19  | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 0    | 0 to 9    | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 100  | 90 to 100 | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 9    | 0 to 9    | POP Icon Keys   |
      | UNIFIED BATTERY  | POP Icon Keys   | 10   | 10 to 19  | POP Icon Keys   |
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

  Scenario Outline: Removing the state directory takes the plugin's folder and nothing else
    # Still passes if: the battery folder is empty
    # test: tests/test_battery.py::remove_state
    Given a state home with the logitech-keys folder holding applied.json and battery files, and another folder beside it
    When remove-state runs <mode>
    Then <result>

    Examples:
      | mode        | result                                                                       |
      | for real    | the logitech-keys folder is gone and the other folder is byte-identical      |
      | as a dry run| nothing is removed and the folder it would remove is printed                 |
      | when there is no folder | it exits 0 and changes nothing                                   |
