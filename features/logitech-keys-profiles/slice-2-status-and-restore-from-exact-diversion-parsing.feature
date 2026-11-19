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

  Scenario Outline: The battery is an object from the keyboard's report, the query, or null
    # Still passes if: the battery line carries an extra status word
    # test: tests/test_status.py::battery_values
    Given the report file holds <report> and Solaar prints <query>
    When the status is read
    Then the battery is <battery>

    Examples:
      | report                                                  | query                      | battery                                         |
      | a report at 10:00 in the 10 to 19 bucket                | Battery: 100%              | value 15, source report, at 10:00               |
      | a report from before the keyboard's last connect, in the 10 to 19 bucket | Battery: 100% | value 15, source report (the report is kept: D18) |
      | a report in the 10 to 19 bucket                         | Battery: 12%               | value 12, source query (the lower query wins)   |
      | a report in the 10 to 19 bucket                         | Battery: 15%               | value 15, source report (equal: the report stays) |
      | a report in the 10 to 19 bucket                         | Battery: 16%               | value 15, source report                         |
      | a report in the 90 to 100 bucket                        | Battery: 20%               | value 20, source query                          |
      | the helper wrote the 10 to 19 bucket at 08:00, then the 20 to 29 bucket at 10:00 | Battery: 100% | value 25, source report, at 10:00 (the newer report wins) |
      | no report file                                          | Battery: 100%              | value 100, source query                         |
      | no report file                                          | Battery: 80%               | value 80, source query                          |
      | no report file                                          | Battery: 0%                | value 0, source query                           |
      | no report file                                          | no battery line            | null                                            |
      | a damaged report file                                   | Battery: 80%               | value 80, source query                          |
      | a report with a bucket above 100                        | Battery: 80%               | value 80, source query                          |
      | a report at 10:00 in the 0 to 9 bucket                  | no battery line            | value 5, source report, at 10:00                |

  Scenario: The report file is read for the right keyboard only
    # Still passes if: the other keyboard's file holds an older report
    # test: tests/test_status.py::battery_per_slug
    Given a report file for the MX Keys for Mac and none for the POP Icon Keys
    When the status is read for both
    Then only the MX Keys for Mac shows a report and the POP Icon Keys falls back to its query

  Scenario Outline: The battery choice is one function and ignores connect times
    # Still passes if: the report's age or the query's level differs
    # test: tests/test_status.py::choose_battery_rule
    Given choose_battery is called with <report> and <query>
    Then it returns <result>
    And battery_for uses that function and no other comparison of a report and a query
    And no connect time is an input of battery_for or choose_battery

    Examples:
      | report                  | query                   | result                                         |
      | report 15 (any age)     | query 100               | the report (the owner's case, an old report still wins) |
      | report 15               | query 12                | the query, source query                        |
      | report 15               | query 15                | the report (equal)                             |
      | report 15               | query 16                | the report                                     |
      | report 95               | query 20                | the query, source query                        |
      | report 15               | none                    | the report                                     |
      | none                    | query 100               | the query, source query (the widget says Full?) |
      | none                    | query 80                | the query, source query                        |
      | none                    | none                    | null                                           |

  Scenario Outline: The status carries a backend block and only known key states
    # Still passes if: the backend's label text changes
    # test: tests/test_status.py::status_contract
    Given the status built for <backend> in <situation>
    When the contract check runs
    Then the JSON has schema 1, a backend block with name, experimental, installed, running, usable, problem, liveKeyState, otherRunning and canStart, and every key state is one of routed, dropped, notSetUp, absent, unsupportedByBackend or unknown
    And <rule>

    Examples:
      | backend  | situation                              | rule                                                                  |
      | Solaar   | the POP Icon Keys, all keys routed     | liveKeyState is true and experimental is false                        |
      | Solaar   | only Solaar running                    | otherRunning is null                                                  |
      | Solaar   | both daemons running                   | otherRunning is "openlogi"                                            |
      | OpenLogi | the synthetic OpenLogi sample          | liveKeyState is false and no key is dropped and no key is routed      |
      | OpenLogi | the synthetic OpenLogi sample          | every key is unsupportedByBackend with reason notImplemented          |
      | OpenLogi | the synthetic OpenLogi sample          | the battery source is backend and level may be null                   |
      | OpenLogi | the sample with one extra optional field in the backend block | the contract check passes (backend fields are additive)  |

  Scenario Outline: The contract check rejects a status that breaks its own rules
    # Still passes if: the other keys of the status are reordered
    # test: tests/test_status.py::validate_status_rejects
    Given a valid status changed so that <defect>
    When validate_status runs
    Then it rejects the status naming <named>

    Examples:
      | defect                                                          | named                    |
      | a key is dropped while liveKeyState is false                    | that key's cid and state |
      | a key is routed while liveKeyState is false                     | that key's cid and state |
      | a key has a state outside the six                               | that key's cid and state |
      | an unsupportedByBackend key has no reason                       | that key's cid           |
      | a key is unknown but the keyboard has no readProblem            | that keyboard's slug     |
      | the schema is 2                                                 | the schema field         |

  Scenario: The committed samples match the builder and the OpenLogi one is labelled synthetic
    # Still passes if: the sample keyboards' battery numbers change
    # test: tests/test_status.py::samples_match_builder
    Given tests/qml/status-sample.json and tests/qml/status-sample-openlogi.json
    Then each equals the builder's output for its fixed input (the Solaar sample: POP Icon Keys battery 15 from a report at 1700000000, MX Keys for Mac battery 80 from a query; the OpenLogi sample: one online POP Icon Keys, battery 42, level good, read at 1700000000)
    And the OpenLogi sample carries the label "synthetic: doc-derived USAGE.md @9ca7ef0" and no real device name

  Scenario Outline: The keyboard's Set OS value is read without any write
    # Still passes if: Solaar prints the OS list in another order
    # test: tests/test_status.py::os_mode_read
    Given the keyboard's block has <lines>
    When its OS mode is read
    Then the mode is <mode>

    Examples:
      | lines                                  | mode      |
      | Set OS (saved): MacOS and Set OS: MacOS | MacOS     |
      | only Set OS: Windows                   | Windows   |
      | Set OS (saved): MacOS and Set OS: Linux | Linux (the live line wins) |
      | no Set OS line (older Solaar)          | unknown   |

  Scenario Outline: Solaar not usable, or nothing profiled connected
    # Still passes if: the helper takes a little longer to run
    # test: tests/test_status.py::solaar_states
    Given <situation>
    When the status helper runs
    Then it exits 0 and prints valid JSON with backend installed <installed>, running <running> and <keyboards> keyboards

    Examples:
      | situation                                              | installed | running | keyboards |
      | Solaar is not installed                                | false     | false   | no        |
      | Solaar is installed, its background process is not running and no profiled keyboard is saved | true | false | no  |
      | Solaar is installed, its background process is not running and the POP Icon Keys is saved (the per-device show works without the daemon) | true | false | one, listed from the per-device read, keys that look lost are dropped |
      | Solaar runs with no profiled keyboard connected        | true      | true    | no        |
      | Solaar runs and records only a mouse                   | true      | true    | no        |
      | a one-off solaar show runs beside the background process | true   | true    | no        |
      | a solaar show call times out and Solaar has no saved entry for a profiled keyboard | true | true | no |
      | a solaar show call times out and Solaar has a saved entry for the POP Icon Keys | true | true | one, with unknown keys |

  Scenario Outline: Status queries each profiled device on its own and never runs solaar show all
    # Still passes if: the selectors are queried in another order
    # test: tests/test_status.py::per_device_queries
    Given Solaar has saved entries for <saved> and the profiles are the shipped ones
    When the status is read with a recording run function
    Then the recorded argv list is exactly <commands>, in that order
    And no command is solaar show all

    Examples:
      | saved                                                  | commands                                                                              |
      | the POP Icon Keys and the MX Keys for Mac              | two calls: solaar show "MX Keys for Mac", then solaar show "POP Icon Keys" (slug order) |
      | only the POP Icon Keys                                 | the same two calls                                                                     |
      | a POP Icon Keys saved under the name "POP Keys Renamed", same model id | three calls: "MX Keys for Mac", "POP Icon Keys", "POP Keys Renamed" (saved names after the profile names) |
      | a mouse only                                           | the same two profile-name calls and no third                                           |

  Scenario Outline: A returned block must be the profiled device
    # Still passes if: the other block is printed before the profiled one
    # test: tests/test_status.py::per_device_identity
    Given the call for the selector "POP Icon Keys" prints <blocks>
    When the status is read
    Then <result>

    Examples:
      | blocks                                                                    | result                                                                                  |
      | the POP Icon Keys block with Model ID B38F00000000                         | the POP Icon Keys section has its states and the selector is not ambiguous               |
      | a block named POP Icon Keys with another Model ID                           | no section appears for it and the selector is ambiguous                                  |
      | the POP Icon Keys block and a block named POP Icon Keys Mini                | the POP Icon Keys section has its states and the selector is ambiguous, so restore sends nothing |
      | a block with the POP Icon Keys model id and another printed name            | the POP Icon Keys section appears (matched by model id)                                  |
      | a block with an all-zero model id and the exact name POP Icon Keys          | the POP Icon Keys section appears (matched by exact name)                                |

  Scenario Outline: A saved-entry name that is unsafe as a selector is skipped
    # Still passes if: the hostile entry is saved before or after the real one
    # test: tests/test_status.py::hostile_saved_names
    Given Solaar has a saved entry for the POP Icon Keys (model id B38F00000000) whose name is <name>
    When the selectors are built and the status is read with a recording run function
    Then the recorded argv list is exactly solaar show "MX Keys for Mac" then solaar show "POP Icon Keys" and no argv holds <name>
    And the POP Icon Keys is still found through its profile name

    Examples:
      | name                                  |
      | -x                                    |
      | --help                                |
      | a name with a double quote inside     |
      | a name with a newline inside          |

  Scenario: A complete POP block is kept when its call prints a second header and then crashes
    # Still passes if: the traceback text is a different exception
    # test: tests/test_status.py::truncated_after_complete_block
    Given the call for the selector "POP Icon Keys" prints the recorded POP block, then the header of a second device whose name contains that selector (the synthetic "POP Icon Keys Mini") and then a UnicodeDecodeError traceback, exit status 1
    When the status is read for the POP Icon Keys with a saved entry
    Then the POP Icon Keys keys have the states of its block, because the next header follows it
    And the second device is incomplete, matches no profile and makes the selector ambiguous
    And no key is dropped, notSetUp or absent because of the truncation

  Scenario: One keyboard's call crashes while the other keyboard's call works
    # Still passes if: the crashing call is made first or last
    # test: tests/test_status.py::one_call_crashes
    Given the call for the selector "MX Keys for Mac" exits 1 with the UnicodeDecodeError traceback and no block, the call for "POP Icon Keys" prints its recorded block, and both keyboards have saved entries
    When the status is read
    Then the POP Icon Keys keys have the states of its block
    And the MX Keys for Mac has every key unknown and the readProblem solaarCrashed

  Scenario Outline: A failed call is unknown for a known keyboard and silent for an unknown one
    # Still passes if: the failing call also printed a warning line
    # test: tests/test_status.py::failed_call_unknown
    Given the call for a profiled keyboard <failure> and <saved>
    When the status is read
    Then <result>

    Examples:
      | failure                                                         | saved                       | result                                                              |
      | exits 1 with a UnicodeDecodeError traceback and no block         | a saved entry for it        | a section with every key unknown and readProblem solaarCrashed       |
      | exits 1 with a traceback after printing its header only          | a saved entry for it        | a section with every key unknown (the half block is not complete)    |
      | times out                                                        | a saved entry for it        | a section with every key unknown and readProblem timeout             |
      | exits 0 with no output                                           | a saved entry for it        | a section with every key unknown and readProblem noOutput            |
      | exits 1 with no device found matching its name                   | a saved entry for it        | no section (not present)                                             |
      | exits 1 with a traceback and no block                            | no saved entry              | no section                                                           |

  Scenario: An unknown keyboard is valid status and is never restored
    # Still passes if: the other keyboard has a different battery level
    # test: tests/test_status.py::unknown_not_warning_not_restored
    Given the MX Keys for Mac is unknown and the POP Icon Keys is routed
    When the status is built, validated and the restore plan is made for each keyboard
    Then validate_status accepts it, the unknown keys carry no reason and the keyboard has readProblem set
    And the restore plan for the MX Keys for Mac sends nothing and exits 0 with a skipped line saying it could not read the keyboard

  Scenario: An unknown keyboard beside a dropped one restores only the dropped one
    # Still passes if: the unknown keyboard's readProblem code differs
    # test: tests/test_status.py::unknown_beside_dropped
    Given the MX Keys for Mac is unknown and the POP Icon Keys has two dropped keys
    When the status is built and the restore plan is made for each keyboard
    Then the restore plan for the POP Icon Keys lists its two dropped keys and the plan for the MX Keys for Mac lists none
    And the icon needs attention because of the POP Icon Keys only, and the unknown keyboard contributes nothing to the warning

  Scenario: The synthetic truncation fixture is built from the recording and labelled
    # Still passes if: the recorded POP fixture is re-recorded with other battery numbers
    # test: tests/test_status.py::synthetic_truncation_fixture
    Given the test that builds the truncated output
    Then it is the recorded masked POP fixture text followed by the header of a second device whose name contains the selector and the traceback text
    And it is labelled synthetic with the date and the source of the traceback and no profile uses it as verification

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
    Given the stub's solaar show command prints a block for every device whose name contains its selector argument, and Solaar has a device named <matched> and another device named <other>
    When the restore helper runs for the profile that matches the first
    Then <result>

    Examples:
      | matched       | other                | result                                                        |
      | POP Icon Keys | POP Icon Keys Mini   | the selector returns both blocks: nothing is sent, it exits 1 and a skipped line says the name also matches the other device |
      | POP Icon Keys | MX Keys for Mac      | control row: the name is not contained in the other, the selector returns only its own block, the dropped keys are sent and it exits 0 |
      | POP Icon Keys | none                 | the selector returns only its own block: the dropped keys are sent and it exits 0 |

  Scenario Outline: The restore helper prints exactly four kinds of line
    # Still passes if: the wording after the prefix changes
    # test: tests/test_status.py::restore_line_set
    Given <situation>
    When the restore helper runs
    Then it prints <line> on <stream> and nothing else matches a different prefix

    Examples:
      | situation                                      | line                                   | stream  |
      | a key is sent again                            | restored: <key>                        | stdout  |
      | one key's command fails                        | failed: <key>                          | stderr  |
      | Solaar is not installed or not running         | error: <text>                          | stderr  |
      | an ambiguous selector or an unknown keyboard   | skipped: <reason>                      | stderr  |

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

  Scenario Outline: The status says whether the backend can be started
    # Still passes if: the backend's label text changes
    # test: tests/test_status.py::can_start
    Given <backend> is <install> and <running>
    When the status helper runs
    Then backend.canStart is <canStart> and backend.running is <running value>

    Examples:
      | backend  | install       | running       | canStart | running value |
      | Solaar   | installed     | not running   | true     | false         |
      | Solaar   | installed     | running       | false    | true          |
      | Solaar   | not installed | not running   | false    | false         |
      | OpenLogi | installed     | not running   | false    | false         |
      | OpenLogi | installed     | running       | false    | true          |

  Scenario Outline: The Start Solaar helper starts Solaar hidden and changes nothing else
    # Still passes if: the helper's one-line message is reworded
    # test: tests/test_status.py::start_helper
    Given <situation> in a sandbox with stub solaar, pgrep and setsid
    When bin/logitech-keys-start runs
    Then it exits <exit> and <effect>
    And the sandbox Solaar and Hyprland config files and the state directory are byte-identical to before

    Examples:
      | situation                              | exit | effect                                                              |
      | Solaar is installed and not running    | 0    | the stub is started once through setsid with --window=hide          |
      | Solaar is already running              | 1    | nothing is started and the line is the sentence "Solaar is already running." |
      | Solaar is not installed                | 1    | nothing is started and the line is the sentence "Solaar is not installed." |
      | setsid cannot start Solaar             | 1    | the line is a sentence that says it could not start Solaar and names the command to try |

  Scenario Outline: A query or backend battery figure is never written to the state directory
    # Still passes if: the figure shown differs by a percent
    # test: tests/test_status.py::battery_not_persisted
    Given a battery state directory and a <source> figure of <value> and no report file
    When the status is built and printed
    Then the battery shows source <source> and no file under the state directory was created or changed

    Examples:
      | source  | value |
      | query   | 100   |
      | query   | 73    |
      | backend | 100   |

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
