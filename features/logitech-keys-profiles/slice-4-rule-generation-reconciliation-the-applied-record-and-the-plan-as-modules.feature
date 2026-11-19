Feature: Solaar rules are generated from profiles and recognised in every shape

  Scenario: The v0.3 command line behaves as before the split
    # Still passes if: the usage message wording changes
    # test: tests/test_edit.py::v03_golden
    Given outputs recorded from the v0.3 edit commands before the split
    When the same commands run after the split
    Then every output and exit code is identical apart from the corrected key-to-id pairing

  Scenario: Rules come from the profile and the action table
    # Still passes if: the comment text above a rule changes
    # test: tests/test_rules.py::rules_from_profile
    Given the POP Icon Keys profile
    When its rules are generated
    Then each mapped key has one rule that runs the action's command
    And every rule is restricted to that keyboard by name and carries no model condition

  Scenario: Generated rules load in Solaar's own rule loader
    # Still passes if: the generated rules carry extra comments
    # test: tests/test_rules.py::solaar_loads_rules
    Given the rules generated for both shipped profiles
    When Solaar's own rule loader reads them
    Then it loads one rule per key with the same key name, device names and arguments
    And a missing loader counts as a failure on the development machine

  Scenario Outline: A rule fires only for its own keyboard
    # Still passes if: the generated rules carry extra comments
    # test: tests/test_rules.py::rules_fire_only_for_own_keyboard
    Given a synthetic profile in a temporary folder that also maps a key called Screen Capture
    And the rules generated for the POP Icon Keys, the synthetic keyboard and the MX Keys for Mac
    When Solaar's own evaluator checks <rule of> against a fake <device>
    Then the rule fires: <fires>

    Examples:
      | rule of                    | device             | fires |
      | the POP Icon Keys rule     | POP Icon Keys      | yes   |
      | the POP Icon Keys rule     | synthetic keyboard | no    |
      | the synthetic keyboard rule| synthetic keyboard | yes   |
      | the synthetic keyboard rule| POP Icon Keys      | no    |
      | the MX Keys for Mac rule   | POP Icon Keys      | no    |
      | the POP Icon Keys rule     | a device whose name only contains POP Icon Keys | no |

  Scenario Outline: Profile and action text cannot reach YAML, Lua or the shell unescaped
    # Still passes if: the rule keeps a trailing newline
    # test: tests/test_rules.py::escaping_sinks
    Given <text> in <place>
    When rules and Lua are generated
    Then <result>

    Examples:
      | text                                         | place              | result                                                             |
      | a double quote                               | a profile label    | the reader refuses the profile before anything is generated       |
      | two closing square brackets                  | a Hyprland chord   | the reader refuses the profile before anything is generated       |
      | a quote, colon, comma, brackets and a hash   | an action argument | the rule parses back to the same arguments                        |
      | a quote and a backslash                      | an action argument | the Lua line is a string that evaluates back to the same command  |
      | spaces and a single quote                    | an action argument | the shell form splits back to the same argument list              |

  Scenario: The action table drives the rules
    # Still passes if: the generated rule gains a comment line
    # test: tests/test_rules.py::actions_table_drives_rules
    Given a temporary action table where one action's arguments changed
    When the rules and Lua are generated for a profile using that action
    Then the generated rule and Lua line carry the changed arguments

  Scenario: A chord bound by two keyboards is written once
    # Still passes if: the Lua comment text changes
    # test: tests/test_rules.py::lua_dedupes_chords
    Given two profiles that bind the same chord to the same action
    When the Lua is generated
    Then the chord is bound once

  Scenario: A chord the user already bound is left alone
    # Still passes if: the user's binding uses a different label
    # test: tests/test_rules.py::lua_existing_bind
    Given a bindings file where the user already bound SUPER + CTRL + Q outside the plugin's block
    When the plan is computed
    Then the plan says the chord is already bound and generates no binding for it

  Scenario Outline: Existing rules are classified
    # Still passes if: a rule has extra whitespace
    # test: tests/test_rules.py::classify_shapes
    Given a rule on a profiled key that is <rule>
    When the rules are classified
    Then the kind is <kind> and overlap is <overlaps>

    Examples:
      | rule                                                            | kind   | overlaps |
      | the new shape with the profile's Device condition               | plugin | no       |
      | a v0.3 two-line rule                                            | legacy | no       |
      | a v0.3 rule rewritten by Solaar's editor without markers        | legacy | no       |
      | a user's rule on the same key with no Device condition          | other  | yes      |
      | a user's rule with the POP Icon Keys Device and a command not in the action table | other | yes |
      | a user's rule with a Device condition for an unprofiled keyboard| other  | no       |
      | a rule on the key with a different argument list and three lines| other  | yes      |
      | a rule in CRLF line endings that is otherwise the new shape     | plugin | no       |

  Scenario Outline: Legacy command forms are recognised and near misses are not
    # Still passes if: the old helper path points to a different home folder
    # test: tests/test_rules.py::legacy_forms
    Given a rule whose command is <command>
    When the rules are classified
    Then the kind is <kind>

    Examples:
      | command                                                                | kind   |
      | the Show Desktop helper path ending in pop-icon-keys-show-desktop under /home/alice | legacy |
      | the same helper path under /home/bob/.local/bin                        | legacy |
      | omarchy-shell omarchy.dock apps (the v0.3 Search list)                 | legacy |
      | omarchy-dictation toggle (the v0.3 Dictation list)                     | legacy |
      | omarchy-shell shell toggle omarchy.emojis (the v0.3 Emoji list)        | legacy |
      | omarchy-capture-screenshot region (the v0.3 Screen Capture list)       | legacy |
      | the helper path with a different file name                             | other  |
      | omarchy-capture-screenshot window (one argument changed)               | other  |

  Scenario: Only the MX Keys for Mac known to Solaar
    # Still passes if: the diversion of other saved keys differs
    # test: tests/test_state.py::mx_only_edits
    Given Solaar's saved settings hold only an MX Keys for Mac
    When setup's edits are computed
    Then 225, 191, 111 and 10 are diverted and 224 and 13 are not
    And the rules run the app launcher, region screenshot, lock and calculator actions

  Scenario: Both Bluetooth and Bolt entries are diverted
    # Still passes if: the entries are in block style instead of flow style
    # test: tests/test_state.py::two_entries_diverted
    Given Solaar saved two entries for one keyboard
    When the diversion is set
    Then both entries get the profile's control ids

  Scenario: A control id dropped from a profile is reset
    # Still passes if: the applied record lists the profiles in another order
    # test: tests/test_state.py::dropped_id_reset
    Given the applied record lists control id 212 for POP Icon Keys and the profile no longer maps it
    When setup's edits are computed
    Then 212 is reset to regular, its rule is removed, and other keys and user rules are unchanged

  Scenario: A dropped id whose keyboard has no saved entry changes nothing
    # Still passes if: the record lists extra profiles
    # test: tests/test_state.py::dropped_id_no_entry
    Given the applied record lists id 212 for a keyboard that Solaar no longer has an entry for
    When setup's edits are computed
    Then the file is unchanged, no error is raised and the keyboard is dropped from the new record

  Scenario: Uninstall resets from the applied record alone
    # Still passes if: the record holds a newer plugin version
    # test: tests/test_state.py::uninstall_from_record
    Given the applied record lists ids and the matched device names for two profiles and the profile files are gone
    When uninstall's edits are computed
    Then exactly those ids are reset on the entries with those names or model ids and the record is deleted

  Scenario: The record is written before the diversion
    # Still passes if: the record lists the profiles in another order
    # test: tests/test_state.py::record_before_divert
    Given a record listing id 212 and a profile that no longer maps it
    When the record is written for the divert and the process stops before the final write
    Then the record on disk lists the old and the new ids together
    And running uninstall's edits resets all of them, a never-diverted id included, and deletes the record

  Scenario Outline: The applied record is read safely
    # Still passes if: the record file has trailing blank lines
    # test: tests/test_state.py::applied_record_robustness
    Given <situation>
    When the record is read or written
    Then <result>

    Examples:
      | situation                                         | result                                                            |
      | no record file                                    | it reads as empty                                                 |
      | a record that is not valid JSON                   | it is refused with code 4 and a message naming the file            |
      | a record whose schema is newer than the plugin's  | it is refused with code 4 and a message naming the file            |
      | XDG_STATE_HOME unset                              | the record lives under the home folder's .local/state              |
      | XDG_STATE_HOME set to a relative path             | it is ignored and the default is used                              |
      | a dry run                                         | no record file or folder is created or changed                     |
      | a write that is interrupted halfway               | the old record is intact and no temporary file is left             |
      | a successful write                                | no backup file is created for the record                           |

  Scenario: The applied record has the backend, the switching marker and per-backend artifacts
    # Still passes if: the record lists the profiles in another order
    # test: tests/test_state.py::applied_backend_shape
    Given a record written for the Solaar backend after setup applied both profiles
    When the record is read back
    Then it has schema 1, the plugin version, backend solaar, switching null and the two profiles with ids, matched names and model ids
    And its artifacts hold the Solaar entries per slug, the rules block, the battery rules and the autostart block, the Hyprland bindings block, and an empty openlogi entry with enabledService false and disabledService false

  Scenario Outline: The switching marker is written before and cleared after a switch
    # Still passes if: the record is indented differently
    # test: tests/test_state.py::switching_marker
    Given a record with backend <from>
    When the record is updated <step>
    Then the record has backend <backend> and switching <switching>

    Examples:
      | from    | step                                      | backend | switching                      |
      | solaar  | before a switch to openlogi begins        | solaar  | from solaar, to openlogi       |
      | solaar  | after the switch finished                 | openlogi | null                          |
      | openlogi | before a switch to solaar begins          | openlogi | from openlogi, to solaar      |

  Scenario: A record with an unknown backend name is refused
    # Still passes if: the record holds extra whitespace
    # test: tests/test_state.py::applied_unknown_backend
    Given a record whose backend is neither solaar nor openlogi
    When the record is read
    Then it is refused with code 4 and a message naming the file

  Scenario: A new keyboard needs data only
    # Still passes if: the third profile's label wording changes
    # test: tests/test_plan.py::new_keyboard_data_only
    Given a third profile and its fixture added to a temporary profiles folder
    When the saved entries are matched, the rules are generated and the plan is computed
    Then the saved entry is found for it, its rules and diversion appear, and the plan lists it as untested, with no code change

  Scenario Outline: The consent plan says what will change and what will not
    # Still passes if: the plan lists the files in another order
    # test: tests/test_plan.py::plan_contents
    Given <situation>
    When the plan is computed
    Then the plan <content>

    Examples:
      | situation                                                    | content                                                                                           |
      | only the POP Icon Keys is known to Solaar                    | has one keyboard block marked tested with its keys and actions and no block for the MX Keys for Mac |
      | both keyboards are known                                     | has a block for each and marks the MX Keys for Mac untested in words                              |
      | Solaar knows no profiled keyboard                            | lists every supported keyboard as tested or untested and says setup applies whichever Solaar then records |
      | the old plugin folder exists                                 | warns that its Re-apply would write old blocks and that two widgets would show                    |
      | unmarked v0.3 rules are present                              | lists each removed rule by key and says backups are made                                          |
      | a user's rule on a profiled key can fire on a handled keyboard | lists it under "your own rules left unchanged" with a note that it will still fire              |
      | an uninstall with no applied record                          | says the v0.3 key set will be reset and lists the exact key names                                 |
      | the file changes are computed                                | lists the Solaar stop and restart notice and every file with its change                           |
      | a keyboard's Set OS differs from its profile's osMode        | warns naming the keyboard, the expected mode and Solaar as the place to change it, and continues  |
      | a keyboard's Set OS cannot be read                           | prints no OS mode warning                                                                         |
      | an untested profile and a keyboard in another OS mode        | still warns (the check covers every profile)                                                      |
