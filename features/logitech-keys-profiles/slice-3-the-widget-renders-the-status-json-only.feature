Feature: One small popup states each keyboard's condition in words and offers four buttons

  Scenario Outline: Each keyboard shows one state in words
    # Still passes if: the glyph beside the words changes
    # test: tests/qml_logic.py::states_in_words
    Given a keyboard whose state is <state>
    When the popup renders
    Then its row says <words>

    Examples:
      | state      | words                                          |
      | ok         | OK                                             |
      | dropped    | 2 keys dropped (the count comes from the JSON) |
      | needsSetup | Needs setup                                    |
      | stopped    | Not active (Solaar stopped)                    |
      | unknown    | Status unknown, then "Could not read this keyboard's status. Choose Refresh." |
      | mismatch   | Preset may not match this keyboard             |

  Scenario: An untested keyboard says so
    # Still passes if: the keyboard is renamed
    # test: tests/qml_logic.py::untested_label
    Given a keyboard with tested false
    When the popup renders
    Then it shows "Untested - may not match your keys" and a tested keyboard does not

  Scenario Outline: The icon warns only for conditions the user can act on
    # Still passes if: a keyboard is listed twice
    # test: tests/qml_logic.py::icon_warning
    Given keyboards in states <states>
    When the icon is drawn
    Then it is <icon>

    Examples:
      | states                  | icon      |
      | ok                      | OK        |
      | ok and unknown          | OK        |
      | ok and dropped          | attention |
      | needsSetup              | attention |
      | stopped                 | attention |
      | mismatch                | attention |

  Scenario: Solaar stopped leads the popup with a banner and a Start Solaar button
    # Still passes if: the banner colour changes
    # test: tests/qml_logic.py::stopped_banner
    Given solaar.running is false and canStart is true
    When the popup renders
    Then the first thing is "Solaar is not running, so these keys do nothing" with a Start Solaar button
    And Restore is hidden, no automatic restore runs and the icon shows even with hide-when-disconnected on
    And with Solaar not installed the banner says how to install it and has no button

  Scenario Outline: The buttons run the right helper or say what to do
    # Still passes if: a button's tooltip wording changes
    # test: tests/qml_logic.py::buttons
    Given <situation>
    When the button is used
    Then <outcome>

    Examples:
      | situation                              | outcome                                                              |
      | Start Solaar is clicked                | bin/logitech-keys-start runs, a pending line shows in place of the button, the popup stays open |
      | the start helper fails                 | its sentence shows                                                   |
      | Open Solaar is clicked with Solaar running | solaar --window=show runs; its tooltip says closing the window quits Solaar |
      | Open Solaar while Solaar is stopped    | it is disabled with "Start Solaar first"                             |
      | Re-apply setup is clicked              | a terminal runs setup, the label says it covers all keyboards, a pending line shows until the next read |
      | Restore is clicked with dropped keys   | bin/logitech-keys-restore runs and a re-read follows after Solaar's save delay |
      | the restore fails                      | the failure line tells what to do                                    |

  Scenario Outline: Battery text is honest about its source and age
    # Still passes if: the level field changes
    # test: tests/qml_logic.py::battery_text
    Given a battery of <battery> and the injected time <now>
    When it is shown
    Then the text is <text>

    Examples:
      | battery                               | text                                      |
      | report, value 15, 3 hours ago         | ≈15%, 3 h ago                             |
      | report, 20 seconds ago or in the future | ≈15%, just now                          |
      | report, 5 minutes ago and 4 days ago  | ≈15%, 5 min ago and ≈15%, 4 d ago         |
      | query 62                              | 62% with no age                           |
      | query 100                             | Full? with the tooltip "The keyboard has not reported its charge yet." |
      | none                                  | Battery unknown with the tooltip "Waiting for the keyboard's next battery report." |

  Scenario: Auto-restore is rate-limited and a manual restore holds it back
    # Still passes if: the interval constant changes by a few seconds
    # test: tests/qml_logic.py::auto_restore
    Given a keyboard that drops keys again and again
    When the status is read repeatedly
    Then at most one automatic restore runs per minute, none while Solaar is stopped or the keyboard is unknown, and a manual restore holds the automatic one back for a minute

  Scenario: Keyboard access and unreadable status
    # Still passes if: the popup width changes
    # test: tests/qml_logic.py::keys_and_errors
    Given the popup is open
    When Escape, Enter, Space and the letters r, s, k, t are pressed and the status is unreadable or has an unknown schema
    Then Escape closes the popup, Enter or Space activates a focused button, the letters run refresh, setup, restore and Start Solaar and are named in the tooltips
    And unreadable status says to refresh and an unknown schema says to reload the shell

  Scenario: The widget knows no keyboard and carries the new identity
    # Still passes if: the manifest description is reworded
    # test: tests/test_setup.sh::panel_no_names, tests/qml_logic.py::identity
    Given Panel.qml and manifest.json
    Then Panel.qml contains no preset key name and no keyboard name, only the status JSON drives it
    And the IPC target and QML module name are logitech-keys, the manifest id is io.github.poornan.logitech-keys, the name Logitech Keys and the version 0.4.0
