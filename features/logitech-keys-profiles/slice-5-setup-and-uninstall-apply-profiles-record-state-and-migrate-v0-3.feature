Feature: Setup and uninstall apply the profiles of the keyboards Solaar knows

  Scenario: Only the POP Icon Keys is known
    # Still passes if: the plan lists the files in another order
    # test: tests/test_setup.sh::"POP only: setup twice, then uninstall"
    Given Solaar has a saved entry only for the POP Icon Keys
    When I run setup and accept
    Then the plan names the POP Icon Keys as tested and no MX Keys for Mac rule or diversion is written
    And the five keys are diverted, the rules and the Lock binding are in marked blocks, and the helper is installed
    And the applied record lists the POP Icon Keys with its ids and matched entry names
    And running setup a second time changes nothing and creates no backup

  Scenario: Rules are in place before keys are diverted
    # Still passes if: the helper is installed before or after the rules block
    # test: tests/test_setup.sh::"rules before diversion"
    Given a sandbox Solaar that logs every command
    When I run setup and accept
    Then the rules block is written before Solaar is stopped for the diversion

  Scenario: Both keyboards in one run, including a shared key name
    # Still passes if: the keyboards are listed in a different order
    # test: tests/test_setup.sh::"two keyboards in one run"
    Given Solaar has saved entries for the POP Icon Keys and the MX Keys for Mac
    And a synthetic third profile in the sandbox plugin copy shares the key name Screen Capture with the POP Icon Keys
    When I run setup and accept
    Then the plan names every keyboard and marks the MX Keys for Mac and the synthetic keyboard untested
    And each keyboard's keys are diverted and one marked block holds every keyboard's rules
    And each rule carries its own keyboard's Device condition so a shared key name runs its own action only

  Scenario Outline: The plan is shown first and nothing changes unless I accept
    # Still passes if: the prompt wording changes
    # test: tests/test_setup.sh::"declining, and no terminal"
    Given any Solaar state
    When <action>
    Then <result>

    Examples:
      | action                                  | result                                                                      |
      | I run setup and answer no               | exit 0, "Nothing changed", no file changed and Solaar not stopped           |
      | I run setup with no terminal and without yes | exit non-zero saying to re-run with --yes, nothing changed             |
      | I run setup with --dry-run              | exit 0 with a diff, no file written, no applied record created              |
      | I run uninstall and answer no           | exit 0, "Nothing changed"                                                   |

  Scenario: Fresh install, Solaar has not seen a profiled keyboard
    # Still passes if: Solaar needs a second wait before it records the keyboard
    # test: tests/test_setup.sh::"fresh install: first read knows none, second knows both"
    Given Solaar's saved settings hold no profiled keyboard
    And a sandbox Solaar that records the POP Icon Keys and the MX Keys for Mac once it has been started
    When I run setup
    Then the plan lists every supported keyboard as tested or untested and says setup applies whichever Solaar then records
    And declining exits 0 with nothing changed
    And accepting starts Solaar once to record the keyboards, then applies both profiles and leaves Solaar running
    And the applied record lists both keyboards

  Scenario Outline: Solaar never records a supported keyboard
    # Still passes if: the retry wait is shortened
    # test: tests/test_setup.sh::"keyboard never seen by Solaar"
    Given Solaar still records <recorded> after the wait
    When setup finishes
    Then it exits 2, says to connect the keyboard and run setup again and names the supported keyboards
    And no applied record is written and no rule or Lock binding is written, and Solaar is running

    Examples:
      | recorded                  |
      | nothing                   |
      | only a mouse              |

  Scenario: Setup records the backend and its artifacts
    # Still passes if: the artifact lists are in another order
    # test: tests/test_setup.sh::"applied record backend and artifacts"
    Given Solaar has a saved entry for the POP Icon Keys
    When I run setup and accept
    Then the applied record says backend solaar and switching null
    And its artifacts name the Solaar entries, the rules block, the battery rules, the autostart block and the Hyprland bindings block

  Scenario: Setup installs the battery helper and the battery rules
    # Still passes if: the helper is installed before or after the rules block
    # test: tests/test_setup.sh::"battery helper and rules installed"
    Given Solaar has a saved entry for the POP Icon Keys, whose profile has a battery feature
    When I run setup and accept
    Then the logitech-keys-battery helper is installed beside the Show Desktop helper
    And the rules block holds ten battery rules for the POP Icon Keys and each one runs that helper with the keyboard's slug
    And running setup again changes nothing and creates no backup

  Scenario: Uninstall removes the state directory and nothing else
    # Still passes if: the state directory holds an extra empty folder
    # test: tests/test_setup.sh::"uninstall removes the state directory", tests/test_battery.py::remove_state
    Given setup ran and the battery folder holds a report for the POP Icon Keys
    When I run uninstall and accept
    Then the whole logitech-keys state directory, the applied record and the battery files included, is gone
    And no other folder under the state home is touched and the plan listed the removal
    And a dry run removes nothing

  Scenario Outline: Setup warns about a different OS mode and continues
    # Still passes if: the warning wording changes
    # test: tests/test_setup.sh::"os mode precondition"
    Given the sandbox Solaar reports the keyboard's Set OS as <mode>
    When I run setup
    Then <result>

    Examples:
      | mode                  | result                                                                                          |
      | MacOS                 | the plan has no OS mode warning                                                                 |
      | Windows               | the plan warns naming the keyboard, the expected mode MacOS and Solaar, and accepting still applies the profile |
      | no Set OS line        | the plan has no OS mode warning                                                                 |

  Scenario: Setup and uninstall reach a backend only through its lifecycle functions
    # Still passes if: the lifecycle function bodies change
    # test: tests/test_setup.sh::"setup uses the lifecycle seam"
    Given the setup and uninstall scripts
    Then they call stop, start, running and installed only through the solaar_ functions of lib/backends/solaar.sh
    And no bash code reads config.yaml, rules.yaml or a profile directly

  Scenario: Uninstall after setup
    # Still passes if: the backups are left in place
    # test: tests/test_setup.sh::"uninstall after two keyboards"
    Given setup applied both profiles
    When I run uninstall and accept
    Then every recorded control id is regular again and the record is deleted
    And the marked blocks and the helper are gone and my own rules and bindings are byte-identical

  Scenario: A later profile drops a control id
    # Still passes if: the profile's other keys are reordered
    # test: tests/test_setup.sh::"later profile drops an id"
    Given the record lists id 212 for the POP Icon Keys and the shipped profile no longer maps it
    When I run setup and accept
    Then 212 is regular, its rule is gone, and the keys still mapped and user rules are untouched

  Scenario: Setup stopped between the two record writes leaves a record uninstall can use
    # Still passes if: the stop happens a little earlier or later in the wait
    # test: tests/test_setup.sh::"setup stopped between the record writes, then uninstall"
    Given the record lists id 212 and the profile no longer maps it
    When I run setup, accept, and stop it while it waits for Solaar
    Then the record on disk lists the old and the new ids together
    And uninstall afterwards resets every id and deletes the record

  Scenario Outline: A damaged or unfamiliar applied record stops setup and uninstall before any change
    # Still passes if: the record's JSON is indented differently
    # test: tests/test_setup.sh::"applied record problems"
    Given <record>
    When I run <command> and accept
    Then <result>

    Examples:
      | record                                      | command   | result                                                                       |
      | a file that is not valid JSON               | setup     | exit 1, a message naming the file, nothing changed                           |
      | a record with a newer schema                | uninstall | exit 1, a message naming the file and saying to update the plugin, nothing changed |
      | XDG_STATE_HOME unset                        | setup     | the record is written under the home folder's .local/state                   |
      | XDG_STATE_HOME set to a relative path       | setup     | it is ignored and the default folder is used                                 |

  Scenario: Upgrade from v0.3
    # Still passes if: the old backups are left in place
    # test: tests/test_setup.sh::"upgrade from v0.3"
    Given a v0.3 install with pop-icon-keys blocks in the rules, bindings and autostart and the old helper
    When I run the new setup and accept
    Then each file has one logitech-keys block and no pop-icon-keys block and one copy of each rule
    And the old helper is gone and the new helper is installed and my own rules and bindings are unchanged

  Scenario: Setup after a migration is a no-op
    # Still passes if: the sandbox folder names differ
    # test: tests/test_setup.sh::"setup after migration changes nothing"
    Given setup has just migrated a v0.3 install
    When I run setup again and accept
    Then no file changes and no backup file is created

  Scenario: v0.3 rules that Solaar's editor rewrote without markers
    # Still passes if: Solaar's editor reordered the keys in the file
    # test: tests/test_setup.sh::"rules rewritten by Solaar's editor (markers gone)"
    Given the rules contain the v0.3 rules without markers, one with the pop-icon-keys-show-desktop path
    When I run the new setup and accept
    Then they are replaced, not duplicated
    And a user rule on one of those keys is reported under "your own rules left unchanged" and left alone

  Scenario: A legacy two-line rule is listed before it is removed
    # Still passes if: the backups are pruned to the newest three
    # test: tests/test_setup.sh::"legacy rules listed and backed up"
    Given an unmarked v0.3 rule of two lines with a Key and an Execute and no Device condition
    When I run the new setup
    Then the plan lists that rule by key as removed
    And after accepting, the rules file has a backup holding the original rule

  Scenario: The old plugin is still installed
    # Still passes if: the warning is also printed on standard error
    # test: tests/test_setup.sh::"old plugin warning"
    Given the plugin folder io.github.poornan.pop-icon-keys exists
    When I run setup
    Then the plan warns that its Re-apply would write old blocks and that two widgets would show

  Scenario Outline: Uninstall removes both generations
    # Still passes if: the backups are left in place
    # test: tests/test_setup.sh::"uninstall removes both generations"
    Given an install that is <state>
    When I run uninstall and accept
    Then every artifact of <artifacts> is gone and everything else in the files is byte-identical to before setup

    Examples:
      | state                                               | artifacts                                                                              |
      | v0.3 only, with marked blocks and the old helper    | the old blocks, the old helper and the old diversion                                   |
      | v0.3 only, with unmarked legacy rules               | the legacy rules, the old helper and the old diversion                                 |
      | mixed: old blocks and new blocks                    | old and new blocks, both helpers, legacy rules and the recorded diversion              |
      | new only                                            | the new blocks, the helper, the recorded diversion and the record                      |

  Scenario: Uninstall without an applied record resets the v0.3 key set
    # Still passes if: the list of key names is printed in another order
    # test: tests/test_setup.sh::"uninstall without a record"
    Given a v0.3 install and no applied record
    When I run uninstall
    Then the plan names the exact v0.3 keys it will reset
    And after accepting, those keys are regular again as v0.3 did

  Scenario Outline: The v0.3 safety cases still end as they did
    # Still passes if: the sandbox folder names differ
    # test: tests/test_setup.sh (the v0.3 sections kept, listed in the inventory)
    Given <case>
    When setup or uninstall runs in a sandbox
    Then it ends as it did in v0.3 and changes no file the user did not consent to

    Examples:
      | case                                                  |
      | broken markers                                        |
      | line endings, block position, symlinks and file modes |
      | two saved entries, one in block style                 |
      | a divert-keys id that is not a number                 |
      | Hyprland reload fails                                 |
      | Solaar ignores SIGTERM                                |
      | Solaar takes a few seconds to save and exit           |
      | setup stopped by SIGTERM while it waits for Solaar    |
      | Solaar fails to start again                           |
      | --yes does not install Solaar                         |
      | backups: newest three kept                            |
      | unreadable and unwritable files                       |
      | missing Python yaml module                            |
      | paths with spaces and commas, and a bad HOME          |
      | relative XDG_CONFIG_HOME                              |
      | concurrent runs                                       |
      | uninstall when Solaar is not installed                |
