Feature: Status and restore read each preset keyboard on its own and never crash on Solaar's bug

  Scenario: Only per-device queries run, never solaar show all
    # Still passes if: the timeout value changes
    # test: tests/test_status.py::per_device_argv
    Given the POP Icon Keys and MX Keys for Mac presets and a saved entry matched by model id
    When status is collected with a recording runner
    Then each call is solaar show with one exact selector from the preset names or the matched saved entries
    And no call is solaar show all and no solaar command other than show runs

  Scenario Outline: Each key's state follows the live and saved diversion lines
    # Still passes if: the keys appear in another order in the line
    # test: tests/test_status.py::state_table
    Given a key that is <live> in the live line and <saved> in the saved line
    When the state is read
    Then it is <state>

    Examples:
      | live        | saved       | state    |
      | diverted    | diverted    | routed   |
      | diverted    | regular     | notSetUp |
      | diverted    | not listed  | notSetUp |
      | regular     | diverted    | dropped  |
      | regular     | regular     | notSetUp |
      | not listed  | not listed  | absent   |
      | not listed  | diverted    | dropped  |
      | diverted    | no saved line at all (older Solaar) | routed |
      | regular     | no saved line at all (older Solaar) | notSetUp |

  Scenario: Suffixed key names are matched by cid, not by substring
    # Still passes if: a key label changes
    # test: tests/test_status.py::suffix_names
    Given a diversion line holding "Search / MultiPlatform Search" and "Screen Capture/Print Screen"
    When the POP and MX states are read
    Then the 212 and 191 keys get the states the line shows and no other key is confused with them

  Scenario: A block that is not this keyboard is not this device
    # Still passes if: the look-alike has a different battery level
    # test: tests/test_status.py::lookalike_block
    Given a selector whose output holds the POP Icon Keys block and a block of a device whose name contains it
    When the output is read
    Then the POP block is used, the other block is ignored and the selector is marked ambiguous

  Scenario Outline: Truncated, failed or timed-out output makes unread keyboards unknown
    # Still passes if: the traceback text differs
    # test: tests/test_status.py::truncated_unknown
    Given <situation>
    When status is built
    Then <outcome>

    Examples:
      | situation                                                                  | outcome                                                              |
      | output cut off after a complete POP block and the MX keyboard is saved     | POP keeps its states and the MX keyboard is unknown with solaarCrashed |
      | a call that times out and the keyboard has a saved entry                   | that keyboard is unknown with timeout                                |
      | a call that times out and the keyboard has no saved entry                  | no section for it                                                    |
      | empty output with exit 0 and a saved entry                                 | unknown with noOutput                                                |
      | the reply "no device found matching" and no saved entry                    | no section and no unknown                                            |
      | an unknown keyboard beside a routed one                                    | the unknown one is never restored and never counted toward a warning |

  Scenario: Saved-entry names that would be hostile selectors are skipped
    # Still passes if: a harmless saved name is added
    # test: tests/test_status.py::hostile_names
    Given saved entries named "-x", "a\"b" and one with a newline
    When selectors are chosen
    Then none of them appears in any solaar show call and the keyboard is still found by its preset names

  Scenario Outline: One state per keyboard, with a fixed precedence
    # Still passes if: the keys are listed in another order
    # test: tests/test_status.py::keyboard_state
    Given a keyboard whose keys are <keys> and Solaar is <daemon>
    When the keyboard state is built
    Then it is <state>

    Examples:
      | keys                              | daemon      | state      |
      | all routed                        | running     | ok         |
      | some routed, the rest absent      | running     | ok         |
      | one dropped                       | running     | dropped    |
      | one notSetUp and one dropped      | running     | needsSetup |
      | all absent                        | running     | mismatch   |
      | any unknown                       | running     | unknown    |
      | all routed or dropped             | not running | stopped    |
      | one notSetUp                      | not running | needsSetup |

  Scenario: With Solaar stopped the keyboards are still listed and the button is offered
    # Still passes if: the daemon was started a minute ago
    # test: tests/test_status.py::stopped_status
    Given Solaar is installed and not running and the per-device show still answers
    When status is built
    Then solaar.running is false, solaar.canStart is true and the keyboards are listed
    And with Solaar not installed canStart is false

  Scenario Outline: The battery figure follows the last-report rule
    # Still passes if: the level field is null
    # test: tests/test_status.py::choose_battery
    Given a stored report of <report> and a direct query of <query>
    When the battery is chosen
    Then the result is <result>

    Examples:
      | report                       | query            | result                                  |
      | 15% (bucket 10) 3 hours old  | 100%             | the report, value 15, source report     |
      | 15% (bucket 10)              | 12%              | the query, value 12, source query       |
      | 15% (bucket 10)              | 15%              | the report                              |
      | 15% (bucket 10) 30 days old  | 100%             | the report                              |
      | none                         | 100%             | the query, source query (shown "Full?") |
      | none                         | 62%              | the query, source query                 |
      | none                         | none             | no battery                              |
      | a damaged state file         | 62%              | the query                               |

  Scenario: A query is never persisted
    # Still passes if: the query value differs
    # test: tests/test_status.py::no_persist
    Given a state directory and a status run with a query figure
    When status finishes
    Then the state directory is byte-identical and only the battery helper opens that path for writing

  Scenario Outline: Restore re-applies saved diversion for dropped keys only
    # Still passes if: the log wording changes
    # test: tests/test_status.py::restore_plan
    Given <situation>
    When restore runs with the Solaar stand-in
    Then <outcome>

    Examples:
      | situation                                              | outcome                                                           |
      | the POP has two dropped keys                           | solaar config runs for those two with the block's exact name      |
      | the selector matches two devices                       | that keyboard is skipped                                          |
      | Solaar is not running                                  | nothing runs and the exit says to start Solaar                    |
      | the keyboard is unknown or the key is notSetUp or absent | nothing runs for it                                             |
      | a dropped POP key and a dropped MX key                 | only the named slug is restored when one is given                 |
      | any of the above                                       | no file under the home folder changes                             |

  Scenario Outline: Start Solaar starts it hidden once and says why when it cannot
    # Still passes if: the stand-in takes a moment to start
    # test: tests/test_setup.sh::start_helper
    Given <situation>
    When the start helper runs
    Then <outcome>

    Examples:
      | situation                  | outcome                                                          |
      | Solaar installed, not running | it runs setsid -f solaar --window=hide, writes nothing, exits 0 |
      | Solaar already running     | it exits non-zero with a sentence and starts no second instance  |
      | Solaar not installed       | it exits non-zero with a sentence and runs nothing               |

  Scenario Outline: The daemon is found whatever debug options it runs with
    # Still passes if: the daemon has extra unrelated options
    # test: tests/test_setup.sh::daemon_detection
    Given a process whose command line is <cmdline>
    When daemon detection runs
    Then it is <verdict>

    Examples:
      | cmdline                              | verdict         |
      | solaar -dd --window=hide             | the daemon      |
      | solaar --window hide                 | the daemon      |
      | solaar                               | the daemon      |
      | solaar show "POP Icon Keys"          | not the daemon  |
      | solaar config "POP Icon Keys" a b    | not the daemon  |
      | solaar -dd show all                  | not the daemon  |

  Scenario: Status always exits 0 with valid JSON and every lib module imports alone
    # Still passes if: a new module is added that also imports alone
    # test: tests/test_imports.py::imports_alone, tests/test_status.py::status_helper
    Given Solaar missing, a crashing show or a malformed saved config
    When the status helper runs, and each lib module is imported in a fresh isolated interpreter
    Then the helper prints one valid JSON object, exits 0 and every module and entry script imports and runs under the isolated interpreter
