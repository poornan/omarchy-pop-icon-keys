Feature: The repository gates keyboard contributions and documents them

  Scenario: CI runs the stdlib tests on every push and pull request
    # Still passes if: the runner image version changes
    # test: tests/test_repo.py::workflow_structure
    Given the workflow file
    Then it runs on push and pull request and its permissions are contents read
    And it lists the syntax check and every test file in the tests folder except the QML harness
    And it does not mention quickshell and needs no real Solaar

  Scenario: Every action in the workflow is pinned to a full commit
    # Still passes if: the action's version comment changes
    # test: tests/test_repo.py::actions_pinned
    Given the workflow file
    Then every "uses" line ends in @ followed by a forty-digit hexadecimal commit id

  Scenario: The PR template carries the contributor checklist
    # Still passes if: the checklist items are reordered
    # test: tests/test_repo.py::pr_template_items
    Given the pull request template
    Then it asks for the recorded fixture, masked serials, ids checked against solaar show, only existing action ids, a README row, an appended permanent slug and a truthful verified block
    And it says the backends section is optional and a verified OpenLogi block needs a recorded, non-synthetic fixture

  Scenario: Code owners cover everything and the trusted paths explicitly
    # Still passes if: further owners are added
    # test: tests/test_repo.py::codeowners
    Given the CODEOWNERS file
    Then a catch-all line gives poornan every path
    And profiles/, lib/actions.json and lib/ are listed explicitly for poornan

  Scenario Outline: The README has its sections in the fixed order
    # Still passes if: a section gains a subsection
    # test: tests/test_repo.py::readme_order
    Given the README
    Then the heading for <section> appears <position>

    Examples:
      | section                                | position                          |
      | what it does                           | first                             |
      | supported keyboards                    | after what it does                |
      | install and uninstall                  | after supported keyboards         |
      | upgrading from v0.3                    | after install and uninstall       |
      | rollback                               | after upgrading from v0.3         |
      | troubleshooting                        | after rollback                    |
      | Add your keyboard                      | after troubleshooting             |

  Scenario Outline: The README explains each topic a contributor or user needs
    # Still passes if: the example keyboard changes
    # test: tests/test_repo.py::readme_topics
    Given the README
    Then it mentions <topic> by <keyword>

    Examples:
      | topic                                                         | keyword          |
      | keycaps depend on Fn-swap                                     | Fn               |
      | Solaar may name a cid differently across versions             | cid              |
      | a new profile is a minor release                              | minor            |
      | a fix is a patch release                                      | patch            |
      | the one allowed non-profile change is the action table        | actions.json     |
      | rollback is running v0.4's own uninstall                      | uninstall        |
      | one confirmation covers all keyboards and there is no per-keyboard option | --only |
      | the masking command for serial numbers and unit ids           | 00000000         |
      | the exact local test command                                  | tests/test_profiles.py |
      | testing your keyboard and sending a verified block            | verified         |

  Scenario: Every profile has a README row that says whether it is tested
    # Still passes if: the table gains a column
    # test: tests/test_repo.py::readme_row_per_profile
    Given each profile in profiles/
    Then the README table has a row with its display name
    And the row says tested exactly when the profile has a verified block

  Scenario: The shipped files use the new identity and the old name stays in an allowlist
    # Still passes if: the old name appears in a migration note
    # test: tests/test_repo.py::identity_allowlist
    Given the shipped files
    Then the manifest id is io.github.poornan.logitech-keys
    And the old name pop-icon-keys appears only in files on a fixed allowlist
    And the v0.3 RULES table appears nowhere

  Scenario: The widget source holds no keyboard or key names
    # Still passes if: the widget's layout changes
    # test: tests/test_repo.py::panel_has_no_names
    Given Panel.qml and the shipped profiles
    Then Panel.qml contains none of their keyboard names, key names or key labels

  Scenario: The design records are consistent
    # Still passes if: the ADR text is edited for style
    # test: tests/test_repo.py::design_records
    Given the spec and ADRs
    Then ADR 0005 is accepted and ADR 0006, 0007 and 0008 exist and are accepted
    And the spec has no "Device / Model" condition text, its AC3a does not call the swapped data comments, and it makes no both-tested or jq claim
    And no shipped or design file says the keyboards run in "Linux OS mode" outside a sentence that calls it an error

  Scenario: The README states the MacOS OS mode requirement and never says Linux mode
    # Still passes if: the README's example keyboard changes
    # test: tests/test_repo.py::readme_os_mode
    Given the README
    Then it says the keyboards must be in MacOS OS mode (Solaar Set OS), that the plugin does not change it and that other modes are untested
    And it does not contain the phrase Linux OS mode or Linux mode as a recommendation

  Scenario: The README says to start Solaar hidden and not to close its window
    # Still passes if: the explanation is reworded
    # test: tests/test_repo.py::readme_start_solaar
    Given the README
    Then it says that closing Solaar's window quits Solaar on Omarchy and stops key routing
    And it gives the command solaar --window=hide, says to leave Solaar running and names the widget's Start Solaar button
    And the flag in that command is accepted by the installed solaar --help and is the one the setup script uses for autostart

  Scenario: The README has an experimental OpenLogi section with an install note and no piped installer
    # Still passes if: the AUR package name is cited with a version
    # test: tests/test_repo.py::readme_openlogi
    Given the README
    Then it has a section on OpenLogi that says the support is experimental and read-only, that keys are not mapped, and that setup never installs it
    And it gives the AUR package, the udev reload and `systemctl --user enable --now openlogi-agent.service` as steps the owner runs
    And it warns that OpenLogi's OS layout default may move a keyboard out of MacOS mode
    And no line of the README pipes a download into a shell

  Scenario Outline: The project rules forbid touching the real OpenLogi
    # Still passes if: the rules are reworded
    # test: tests/test_repo.py::claude_md_openlogi_rules
    Given the project rules file
    Then it contains the rule <rule>

    Examples:
      | rule                                                                                                  |
      | never start, stop, restart, enable or disable the developer's OpenLogi agent in tests or reviews     |
      | checksum ~/.config/openlogi/config.toml and ~/.config/systemd/user/ before and after a build         |
      | only the read-only openlogi api status and openlogi api devices commands may run on the real machine  |
      | the backend seam: bash is process lifecycle only, Python does file work, OpenLogi is read-only and experimental |
