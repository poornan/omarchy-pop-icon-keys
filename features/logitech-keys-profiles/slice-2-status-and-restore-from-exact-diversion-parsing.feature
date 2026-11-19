Feature: The status helper reports each profiled keyboard exactly

  Scenario: A routed POP Icon Keys
    # Still passes if: the battery percentage differs
    # test: tests/test_status.py::routed_pop
    Given Solaar shows a POP Icon Keys with all five mapped keys diverted live and saved
    When the status is read
    Then one keyboard section appears with its battery, its display name and the tested flag
    And every mapped key is routed with its label
    And its Lock binding is listed as SUPER + CTRL + Q

  Scenario Outline: The live and saved diversion lines decide each key's state
    # Still passes if: the key is the first or the last in the line
    # test: tests/test_status.py::state_table
    Given a mapped key that is <live> in the live line and <saved> in the saved line
    When the status is read
    Then the key's state is <state>

    Examples:
      | live      | saved         | state    |
      | diverted  | diverted      | routed   |
      | diverted  | regular       | notSetUp |
      | diverted  | not listed    | notSetUp |
      | diverted  | no saved line | routed   |
      | regular   | diverted      | dropped  |
      | regular   | regular       | notSetUp |
      | regular   | not listed    | notSetUp |
      | regular   | no saved line | notSetUp |
      | not listed| diverted      | dropped  |
      | not listed| regular       | notSetUp |
      | not listed| not listed    | absent   |
      | not listed| no saved line | absent   |

  Scenario: Older Solaar with no saved line reports from the live line only
    # Still passes if: the live line lists the keys in a different order
    # test: tests/test_status.py::older_solaar_live_only
    Given Solaar prints a live diversion line and no saved line
    When the status is read
    Then diverted keys are routed and regular keys are not set up and no key is dropped

  Scenario: Derived variants read back as the states they were derived for
    # Still passes if: the derived text lists the keys in a different order
    # test: tests/test_status.py::derived_round_trip
    Given the routed, dropped and not-set-up variants derived for every shipped profile
    When each variant is read
    Then routed gives every mapped key routed, dropped gives every key dropped, and not-set-up gives the intended mix

  Scenario Outline: Suffixed Solaar key names are matched exactly
    # Still passes if: Solaar prints the lines with different spacing
    # test: tests/test_status.py::suffixed_names
    Given a diversion line for <profile> where <regular key> is regular and <diverted key> is diverted
    When the status is read
    Then <diverted key> is routed and <regular key> does not change any other key

    Examples:
      | profile         | regular key  | diverted key                   |
      | POP Icon Keys   | Search       | MultiPlatform Search           |
      | MX Keys for Mac | Print Screen | Screen Capture/Print Screen    |

  Scenario: Control ids are not confused between keys
    # Still passes if: the other three keys are routed or not
    # test: tests/test_status.py::regression_212_266
    Given id 212 is diverted and id 266 is regular in the POP Icon Keys diversion lines
    When the status is read
    Then MultiPlatform Search is routed and Screen Capture is not set up

  Scenario Outline: Solaar's own key table decides which name a control id has
    # Still passes if: the table lists more keys than the profiles use
    # test: tests/test_status.py::key_table_injection
    Given the key table is <table>
    And the diversion line names the key for id 212 as <printed name>
    When the status is read for the POP Icon Keys
    Then the key for id 212 is <state> and the status notes that the table was <note>

    Examples:
      | table                                    | printed name                | state    | note        |
      | a supplied table that agrees with the profile | MultiPlatform Search   | routed   | used        |
      | a supplied table naming id 212 "Search X"| Search X                    | routed   | used        |
      | not available                            | Search X                    | absent   | unavailable |
      | not available                            | MultiPlatform Search        | routed   | unavailable |

  Scenario: A key in neither line is absent
    # Still passes if: the absent key's label changes
    # test: tests/test_status.py::absent_key
    Given a profile key that appears in neither diversion line
    When the status is read
    Then that key is absent and the rest of the keyboard's keys keep their states

  Scenario: A new keyboard needs data only
    # Still passes if: the third profile's label wording changes
    # test: tests/test_status.py::new_keyboard_data_only
    Given a third profile and its recorded fixture added to a temporary profiles folder
    When the status is read for a Solaar that shows that keyboard
    Then the status has a section for it, marked untested, with its keys, and no code changed

  Scenario Outline: Look-alike devices are not the profiled keyboard
    # Still passes if: the look-alike has the same battery level
    # test: tests/test_status.py::lookalike_models
    Given Solaar shows a real MX Keys for Mac and a device named <look-alike> with another model id
    When the status is read
    Then only the real device gets the MX Keys for Mac section

    Examples:
      | look-alike     |
      | MX Keys Mini   |
      | MX Keys S      |
      | MX Keys for Mac Plus |
      | MX Master 4    |

  Scenario: Two keyboards at once
    # Still passes if: the receiver lists the keyboards in another order
    # test: tests/test_status.py::two_keyboards
    Given the POP Icon Keys and the MX Keys for Mac are both connected
    When the status is read
    Then there is one section per keyboard sorted by slug, each with its own keys in profile order and its own tested flag

  Scenario: A keyboard paired but switched off is not listed
    # Still passes if: Solaar prints the offline device's last battery level
    # test: tests/test_status.py::offline_not_listed
    Given Solaar lists a paired POP Icon Keys that is offline and prints no live diversion line for it
    When the status is read
    Then no section appears for it

  Scenario Outline: The battery is a number or null
    # Still passes if: the battery line carries an extra status word
    # test: tests/test_status.py::battery_values
    Given Solaar prints <battery line> for the keyboard
    When the status is read
    Then the battery is <battery>

    Examples:
      | battery line            | battery |
      | Battery: 80%            | 80      |
      | Battery: 0%             | 0       |
      | no battery line         | null    |

  Scenario Outline: Solaar not usable, or nothing profiled connected
    # Still passes if: the helper takes a little longer to run
    # test: tests/test_status.py::solaar_states
    Given <situation>
    When the status helper runs
    Then it exits 0 and prints valid JSON with installed <installed>, running <running> and <keyboards> keyboards

    Examples:
      | situation                                              | installed | running | keyboards |
      | Solaar is not installed                                | false     | false   | no        |
      | Solaar is installed and its background process is not running | true | false   | no        |
      | Solaar runs with no profiled keyboard connected        | true      | true    | no        |
      | Solaar runs and records only a mouse                   | true      | true    | no        |
      | a one-off solaar show runs beside the background process | true   | true    | no        |
      | solaar show takes longer than twenty seconds           | true      | true    | no        |

  Scenario: Restore sends back only the dropped keys of one keyboard
    # Still passes if: the confirmation text changes
    # test: tests/test_status.py::restore_one_keyboard
    Given the POP Icon Keys dropped Dictation and Emoji while the MX Keys for Mac is fine
    When the restore helper runs for the POP Icon Keys
    Then only those two keys are re-sent to that keyboard and nothing is sent for the other

  Scenario: Both keyboards dropped keys and each is restored once
    # Still passes if: the helper handles the two keyboards in the other order
    # test: tests/test_status.py::restore_both_once
    Given both keyboards dropped some keys
    When the restore helper runs once for each
    Then each dropped key is re-sent exactly once, to its own keyboard

  Scenario: Restore addresses the keyboard by the exact name Solaar printed
    # Still passes if: the profile lists the same name too
    # test: tests/test_status.py::restore_exact_name
    Given a keyboard matched by model id whose name differs from the profile's name
    When the restore helper runs for its profile
    Then the commands to Solaar use that device's exact printed name

  Scenario: Restore changes no file
    # Still passes if: Solaar rewrites its own file with identical content
    # test: tests/test_status.py::restore_writes_nothing
    Given a sandbox Solaar configuration with a recorded checksum
    When the restore helper runs
    Then the configuration file's checksum is unchanged

  Scenario Outline: Restore skips an ambiguous selector
    # Still passes if: the refusal is printed to standard error
    # test: tests/test_status.py::restore_ambiguous
    Given Solaar shows a device named <matched> and another device named <other>
    When the restore helper runs for the profile that matches the first
    Then <result>

    Examples:
      | matched       | other                | result                                                        |
      | POP Icon Keys | POP Icon Keys Mini   | nothing is sent, it exits 1 and says the name also matches the other device |
      | POP Icon Keys | MX Keys for Mac      | the dropped keys are sent and it exits 0                      |

  Scenario Outline: Restore reports what went wrong
    # Still passes if: the failed key is listed first
    # test: tests/test_status.py::restore_failures
    Given <situation>
    When the restore helper runs
    Then it exits <exit> and says <message>

    Examples:
      | situation                                  | exit | message                                           |
      | Solaar is not installed                    | 1    | Solaar is not installed                           |
      | Solaar is not running                      | 1    | Solaar is not running and how to start it         |
      | one key's command fails                    | 1    | failed with that key's name                       |
      | a command takes longer than twenty seconds | 1    | failed with that key's name                       |
      | the profile name is unknown                | 1    | no profile of that name                           |
      | the keyboard is not connected              | 0    | nothing to restore                                |

  Scenario Outline: The Show Desktop helper toggles, or says Hyprland is missing
    # Still passes if: the helper prints a confirmation
    # test: tests/test_status.py::show_desktop_helper
    Given hyprctl reports <windows> windows on the active workspace
    When the helper runs
    Then it dispatches <dispatch>

    Examples:
      | windows                  | dispatch                               |
      | 3                        | a focus to the empty workspace         |
      | 0                        | a focus back to the previous workspace |
      | no hyprctl on the path   | nothing, and it exits 1 saying Hyprland is missing |
