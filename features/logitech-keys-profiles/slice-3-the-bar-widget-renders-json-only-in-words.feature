Feature: One bar icon shows every connected profiled keyboard, in words

  Scenario: Two keyboards, one icon, one header line each
    # Still passes if: the sections appear in another order
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
      | notSetUp | no        | Not set up            | no     |
      | absent   | no        | Not found             | yes    |

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
      | one key lost        | two keys not set up       | warning | both buttons                    |

  Scenario: An absent key is dimmed and is not a warning
    # Still passes if: the opacity value used for dimming changes
    # test: tests/qml/shell.qml::absent_dimmed
    Given a key whose state is absent and every other key of the keyboard active
    Then the key's row exists and carries the dimmed flag
    And the icon does not ask for setup

  Scenario: A keyboard with every key absent says so in words
    # Still passes if: the other keyboard is fine or not
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
    Given Solaar is <install>, its background process is <running>, <keyboards> keyboards are connected and hide-when-disconnected is <hide>
    Then the icon is <icon> and setup is <setup>

    Examples:
      | install       | running     | keyboards | hide | icon    | setup     |
      | not installed | not running | no        | on   | shown   | requested |
      | installed     | not running | no        | on   | hidden  | not requested |
      | installed     | not running | one       | on   | shown   | requested |
      | installed     | running     | no        | on   | hidden  | not requested |
      | installed     | running     | no        | off  | shown   | not requested |
      | installed     | running     | one       | on   | shown   | not requested |

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
    And the single-key shortcuts for refresh, setup and restore are named in the buttons' tooltips
    And every state is also stated as text, so no state depends on colour or dimming

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
