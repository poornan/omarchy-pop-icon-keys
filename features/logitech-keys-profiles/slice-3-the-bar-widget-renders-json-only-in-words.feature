Feature: One bar icon shows every connected profiled keyboard, in words

  Scenario: Two keyboards, one icon, one header line each
    # Still passes if: the keyboards' battery figures differ
    # test: tests/qml/shell.qml::two_keyboards_one_icon
    Given the sample status lists the POP Icon Keys and the MX Keys for Mac, all keys active
    Then the bar shows one icon
    And the popup has one section per keyboard, ordered by slug
    And each section starts with one header line holding the keyboard's name, its battery and its one-line status

  Scenario Outline: Every key row says its state in words as well as with a glyph
    # Still passes if: the glyph for a state changes
    # test: tests/qml/shell.qml::key_row_text
    Given a key whose state is <state> and a restore running is <restoring>
    Then its row reads <text> and has a glyph
    And its row has the dimmed flag set to <dimmed>

    Examples:
      | state    | restoring | text                  | dimmed |
      | routed   | no        | Active                | no     |
      | dropped  | no        | Lost                  | no     |
      | dropped  | yes       | Lost, restoring...    | no     |
      | dropped, the backend is stopped | no | Not active (Solaar stopped) | no |
      | notSetUp | no        | Not set up            | no     |
      | absent   | no        | Not found             | yes    |
      | unknown  | no        | Unknown               | yes    |

  Scenario Outline: An untested keyboard is labelled in words
    # Still passes if: the badge colour changes
    # test: tests/qml/shell.qml::untested_label
    Given a keyboard whose status says tested is <tested>
    Then its header shows <badge>

    Examples:
      | tested | badge                                        |
      | false  | the words "Untested - may not match your keys" |
      | true   | no badge                                     |

  Scenario Outline: The icon warns for any keyboard that needs attention
    # Still passes if: the warning also shows a count
    # test: tests/qml/decisions.json (rows "icon"), tests/qml/shell.qml::icon_warning, tests/qml_logic.py::pure_decisions
    Given the first keyboard has <first> and the second keyboard has <second>
    Then the icon is <icon> and the popup offers <offer>

    Examples:
      | first               | second                    | icon    | offer                           |
      | all keys active     | all keys active           | normal  | nothing extra                   |
      | all keys active     | two keys not set up       | warning | Re-apply setup (all keyboards)  |
      | all keys active     | two keys lost, no setup needed | warning | Restore (lost keys only)   |
      | all keys active     | one key not found         | normal  | nothing extra                   |
      | all keys active     | every key unknown (not read) | normal | nothing extra, no Restore button for it |
      | one key lost        | two keys not set up       | warning | both buttons                    |

  Scenario: An absent key is dimmed and is not a warning
    # Still passes if: the opacity value used for dimming changes
    # test: tests/qml/shell.qml::absent_dimmed
    Given a key whose state is absent and every other key of the keyboard active
    Then the key's row exists and carries the dimmed flag
    And the icon does not ask for setup

  Scenario Outline: The tooltip and the section line claim only what was checked
    # Still passes if: the keyboards are listed in another order in the tooltip
    # test: tests/qml/decisions.json (rows "icon"), tests/qml/shell.qml::tooltip_honesty, tests/qml_logic.py::pure_decisions
    Given the status has <situation>
    Then the icon tooltip reads <tooltip> and the section line of the keyboard reads <section>

    Examples:
      | situation                                                      | tooltip                                                          | section                                              |
      | two keyboards, every key routed                                | Logitech Keys: 2 keyboards, all keys active                      | All keys active                                      |
      | one keyboard, four keys routed and one absent                  | Logitech Keys: 1 keyboard, all keys active                       | All found keys active                                |
      | the MX Keys for Mac unread (every key unknown), the POP routed | MX Keys for Mac: status unknown, with its short phrase           | Could not read this keyboard's status. Choose Refresh. If this keeps happening, see Troubleshooting in the README. |
      | the OpenLogi sample (every key unsupportedByBackend)           | Logitech Keys: 1 keyboard, keys not mapped by OpenLogi           | Keys are not mapped by OpenLogi in this version      |
      | one key lost                                                   | the keyboard's name and 1 key lost, then "Open the menu to fix it." | 1 key lost                                        |

  Scenario: A keyboard that could not be read says so and does not warn
    # Still passes if: the POP Icon Keys battery figure differs
    # test: tests/qml/shell.qml::unknown_keyboard
    Given the MX Keys for Mac has every key unknown with a readProblem and the POP Icon Keys is all active
    Then the MX Keys for Mac section shows its keys as Unknown and the line "Could not read this keyboard's status. Choose Refresh. If this keeps happening, see Troubleshooting in the README."
    And the icon tooltip has the line "MX Keys for Mac: status unknown" with the short phrase for its readProblem and does not say all keys active
    And the icon does not warn, no Restore button is offered for it and no automatic restore runs for it
    And the POP Icon Keys section is unchanged

  Scenario: A keyboard with every key absent says so in words
    # Still passes if: the keyboard's battery figure differs
    # test: tests/qml/shell.qml::all_absent_message
    Given a keyboard whose keys are all not found
    Then its section shows the all-absent message with the issue address in plain text rather than a red warning
    And the icon does not ask for setup

  Scenario: A keyboard with more than half its keys absent says so in words
    # Still passes if: the absent keys are not the first ones listed
    # test: tests/qml/shell.qml::mostly_absent_message
    Given a keyboard with three of its five keys not found and two active
    Then its section shows the many-keys-not-found message
    And the two active keys are still listed as Active

  Scenario: Dropped keys are restored for that keyboard only
    # Still passes if: the restore is attempted a little later
    # test: tests/qml/shell.qml::restore_one_keyboard
    Given the MX Keys for Mac has lost keys and the POP Icon Keys has none and auto-restore is on
    Then one restore runs, for the MX Keys for Mac, with its lost keys
    And none is run for the POP Icon Keys

  Scenario: Two keyboards with lost keys are restored once each
    # Still passes if: the two restores run in the other order
    # test: tests/qml/shell.qml::restore_two_keyboards
    Given both keyboards have lost keys and auto-restore is on
    Then one restore runs for each keyboard with its own lost keys and no restore runs twice for one keyboard

  Scenario Outline: Automatic restore follows the setting and the restore in progress
    # Still passes if: the restore button label changes
    # test: tests/qml/decisions.json (rows "restore"), tests/qml/shell.qml::auto_restore_rules
    Given a keyboard has lost keys, auto-restore is <setting> and a restore is <progress>
    Then an automatic restore <starts> and the popup offers the Restore button <offered>

    Examples:
      | setting | progress    | starts         | offered |
      | on      | not running | starts         | yes     |
      | off     | not running | does not start | yes     |
      | on      | running     | does not start | yes, showing Restoring... |

  Scenario Outline: The icon is shown or hidden by what Solaar and the keyboards are doing
    # Still passes if: the tooltip wording changes
    # test: tests/qml/decisions.json (rows "visibility"), tests/qml/shell.qml::visibility_table, tests/qml_logic.py::pure_decisions
    Given Solaar is <install>, its background process is <running>, <keyboards> keyboards are listed by the status and hide-when-disconnected is <hide>
    Then the icon is <icon>, the popup shows <banner> and setup is <setup>

    Examples:
      | install       | running     | keyboards | hide | icon           | banner                                              | setup         |
      | not installed | not running | no        | on   | shown          | the Solaar-not-installed copy                        | requested     |
      | installed     | not running | no        | on   | shown, warning | the Solaar-not-running banner with Start Solaar      | not requested |
      | installed     | not running | no        | off  | shown, warning | the same banner                                      | not requested |
      | installed     | not running | one       | on   | shown, warning | the same banner, the keys read Not active (Solaar stopped) | not requested |
      | installed     | running     | no        | on   | hidden         | no banner                                            | not requested |
      | installed     | running     | no        | off  | shown          | no banner                                            | not requested |
      | installed     | running     | one       | on   | shown          | no banner                                            | not requested |

  Scenario Outline: A stopped backend is shown prominently and Solaar can be started with one click
    # Still passes if: the banner wording changes
    # test: tests/qml/decisions.json (rows "backend stopped"), tests/qml/shell.qml::backend_stopped_banner, tests/qml_logic.py::pure_decisions
    Given the status says <backend> installed <installed>, running <running> and canStart <canStart>, with a keyboard whose keys look lost (the status still lists it, read per device)
    Then the popup <banner>, the icon is <icon>, the Start Solaar button is <button>, manual Restore is <restore> and automatic restore <auto>

    Examples:
      | backend  | installed | running | canStart | banner                                                        | icon    | button | restore | auto            |
      | Solaar   | true      | false   | true     | leads with "Solaar is not running, so these keys do nothing" and words the keys "Not active (Solaar stopped)" | warning | shown  | hidden, with the line "Start Solaar first" | does not run |
      | Solaar   | true      | true    | false    | has no banner                                                  | as before | hidden | offered | follows the setting |
      | Solaar   | false     | false   | false    | says Solaar is not installed and to re-apply setup             | as before | hidden | hidden  | does not run    |
      | OpenLogi | true      | false   | false    | shows the agent problem copy and no Solaar wording             | as before | hidden | hidden  | does not run    |
      | Solaar   | true      | false   | true, after the start helper exited non-zero | adds the helper's line and "Start it hidden with: solaar --window=hide" | warning | shown again | hidden | does not run |

  Scenario: Start Solaar runs the helper once, shows a pending line and then the next status
    # Still passes if: the pending line stays a moment longer
    # test: tests/qml/shell.qml::start_solaar_action
    Given the banner shows a Start Solaar button
    When the button is chosen
    Then bin/logitech-keys-start runs once, the popup stays open and shows "Starting Solaar..." in place of the button until the next status read
    And when the helper exits non-zero its line is shown as printed, with "Start it hidden with: solaar --window=hide", and the button is available again
    And pressing the single key t does exactly what choosing the button does, only while canStart is true
    And no setup, no consent prompt and no file write is involved

  Scenario Outline: Unreadable or unfamiliar status is reported in words
    # Still passes if: the widget reads the status a little later
    # test: tests/qml/shell.qml::status_errors
    Given the status helper prints <output>
    Then the popup says <message>

    Examples:
      | output                              | message                                                  |
      | nothing yet                         | Checking...                                              |
      | text that is not JSON               | Could not read the keyboard status                       |
      | JSON with schema 2                  | This widget does not understand the status ... Reload the shell |
      | JSON with no keyboards, Solaar not running | Solaar is not running, with how to start it       |

  Scenario Outline: A failed restore names the key or says what happened
    # Still passes if: the failed key is listed first
    # test: tests/qml/shell.qml::restore_failure_copy
    Given the restore helper prints <line> and exits 1
    Then the tooltip and popup say <message>

    Examples:
      | line                                     | message                                  |
      | failed: Emoji                            | Could not restore Emoji                  |
      | error: Solaar is not running; start it with: solaar --window=hide | the helper's line as printed |
      | skipped: the name also matches another device | the helper's line as printed          |

  Scenario: Re-apply setup opens a terminal and waits for the next read
    # Still passes if: the terminal program differs
    # test: tests/qml/shell.qml::reapply_setup
    Given any keyboard state
    When Re-apply setup (all keyboards) is chosen
    Then a terminal runs setup, which shows its plan and asks y/N
    And the popup says it covers all keyboards and shows "Waiting for setup to finish in the terminal..." until the next status read

  Scenario: The popup can be used from the keyboard
    # Still passes if: the shortcut letters change
    # test: tests/qml/shell.qml::keyboard_use
    Given the popup is open
    Then Escape closes it and a focused button is activated by Enter or Space
    And the single-key shortcuts for refresh, setup, restore and Start Solaar (r, s, k and t) are named in the buttons' tooltips
    And the banner has an accessible name where Qt allows
    And every state is also stated as text, so no state depends on colour or dimming

  Scenario Outline: The battery reads as a figure, a report age, Full? or unknown
    # Still passes if: the badge colour next to the figure changes
    # test: tests/qml/shell.qml::battery_forms, tests/qml_logic.py::pure_decisions
    Given a keyboard whose battery is <battery>
    Then the header shows <text> with the tooltip <tooltip> and the accessible name <name>

    Examples:
      | battery                                       | text                    | tooltip | name |
      | a report of 15 taken five minutes ago         | ≈15%, 5 min ago         | none    | about 15 percent, 5 minutes ago |
      | a report of 15 taken three hours ago, no newer figure | ≈15%, 3 h ago (the old report is kept) | none | about 15 percent, 3 hours ago |
      | a query figure of 12 that was lower than the report | 12%, no age         | none    | 12 percent |
      | a query figure of 80                          | 80%                     | none    | 80 percent |
      | a query figure of 100                         | Full?                   | The keyboard has not reported its charge yet. | full, not confirmed |
      | a backend figure of 100                       | Full?                   | The keyboard has not reported its charge yet. | full, not confirmed |
      | a backend figure of 42 with no level          | 42%                     | none    | 42 percent |
      | null                                          | Battery unknown         | Waiting for the keyboard's next battery report. | battery unknown |

  Scenario Outline: The report age is one pure function of the report time and an injected now
    # Still passes if: the machine's time zone differs
    # test: tests/qml_logic.py::pure_decisions, tests/qml/decisions.json (rows "age"), tests/qml/shell.qml::battery_age
    Given a report taken at epoch T and the injected now is T plus <elapsed>
    Then the age text is <text>

    Examples:
      | elapsed                                   | text        |
      | 0 seconds                                 | just now    |
      | 59 seconds                                | just now    |
      | 60 seconds                                | 1 min ago   |
      | 59 minutes                                | 59 min ago  |
      | 60 minutes                                | 1 h ago     |
      | 23 hours and 59 minutes                   | 23 h ago    |
      | 24 hours                                  | 1 d ago     |
      | 3 days                                    | 3 d ago     |
      | minus 5 minutes (a report time in the future) | just now |

  Scenario: Keys the backend cannot route are dimmed and are not a warning
    # Still passes if: the dimming opacity changes
    # test: tests/qml/shell.qml::unsupported_by_backend
    Given the synthetic OpenLogi sample where every key is unsupportedByBackend
    Then each key row reads "Not supported by OpenLogi" and carries the dimmed flag
    And the icon does not ask for setup or restore and the section shows the experimental badge
    And battery and connection are still shown

  Scenario Outline: A backend without live key state offers no restore
    # Still passes if: the restore button label changes
    # test: tests/qml/shell.qml::no_restore_without_live_state, tests/qml/decisions.json (rows "restore")
    Given a backend whose liveKeyState is <live> and a keyboard whose keys are <keys>
    Then the popup offers the Restore button <offered> and an automatic restore <auto>

    Examples:
      | live  | keys                    | offered | auto           |
      | true  | lost                    | yes     | starts         |
      | false | routed                  | no      | does not start |
      | false | unsupportedByBackend    | no      | does not start |

  Scenario: Both backends running is shown as a warning that stops nothing
    # Still passes if: the warning is shown above or below the keyboards
    # test: tests/qml/shell.qml::other_backend_running
    Given the status says the other backend is running
    Then the popup says both programs own the receiver and to quit one of them
    And the icon tooltip adds the line "Both Solaar and OpenLogi are running; quit the one you do not want."
    And the widget starts no process and the icon state is decided only by the keys

  Scenario Outline: An unusable backend says what to do in words
    # Still passes if: the Refresh button is renamed
    # test: tests/qml/shell.qml::backend_problems
    Given the backend is not usable with problem <problem>
    Then the popup says <message>

    Examples:
      | problem             | message                                                   |
      | agentUnavailable    | OpenLogi's agent is not responding, with the start command |
      | versionMismatch     | OpenLogi and its agent are different versions              |
      | inventoryNotReady   | OpenLogi is still scanning, choose Refresh in a moment     |
      | unknownSchema       | the widget cannot read OpenLogi's reply, update the plugin |

  Scenario: The widget knows no keyboard
    # Still passes if: the popup spacing changes
    # test: tests/test_repo.py::panel_has_no_names, tests/qml_logic.py::no_names
    Given the widget source and the shipped profiles
    Then the widget source contains none of their keyboard names, key names or key labels

  Scenario: The plugin identity is Logitech Keys
    # Still passes if: the manifest description is reworded
    # test: tests/qml_logic.py::identity, omarchy-plugin-validate .
    Given the manifest and the widget
    Then the id is io.github.poornan.logitech-keys, the name is Logitech Keys and the version is 0.4.0
    And the IPC target and QML module name are logitech-keys
    And the manifest validates
