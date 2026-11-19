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

  Scenario: The README names the repository and every install command uses it
    # Still passes if: the README gains another section
    # test: tests/test_repo.py::readme_repo_url
    Given the README
    Then it contains github.com/poornan/omarchy-logitech-keys and every install command in it uses that address
    And the old repository name omarchy-pop-icon-keys appears only inside the upgrading-from-v0.3 section

  Scenario Outline: The README explains each topic a contributor or user needs, in the right section
    # Still passes if: the example keyboard changes
    # test: tests/test_repo.py::readme_topics
    Given the README
    Then within its <section> section it mentions <topic> by <keyword>

    Examples:
      | section               | topic                                                         | keyword          |
      | Add your keyboard     | keycaps depend on Fn-swap                                     | Fn               |
      | Add your keyboard     | Solaar may name a cid differently across versions             | cid              |
      | Add your keyboard     | a new profile is a minor release                              | minor            |
      | Add your keyboard     | a fix is a patch release                                      | patch            |
      | Add your keyboard     | the one allowed non-profile change is the action table        | actions.json     |
      | rollback              | rollback is running v0.4's own uninstall                      | uninstall        |
      | install and uninstall | one confirmation covers all keyboards and there is no per-keyboard option | --only |
      | Add your keyboard     | the masking command for serial numbers and unit ids           | 00000000         |
      | Add your keyboard     | the exact local test command                                  | tests/test_profiles.py |
      | Add your keyboard     | testing your keyboard and sending a verified block            | verified         |
      | Add your keyboard     | an example validator error line                               | error: profile:  |
      | Add your keyboard     | a worked diff as a fenced block                               | a fenced block whose opening line is the diff language tag |
      | Known issues          | the Solaar host-name bug can break plain solaar show and the workaround | UnicodeDecodeError |
      | troubleshooting       | a keyboard that could not be read shows as Unknown            | Unknown          |
      | OpenLogi              | a switch to OpenLogi disables key mapping in this version     | special keys will do nothing |

  Scenario: The Add your keyboard section has its parts in order
    # Still passes if: a part gains a sentence
    # test: tests/test_repo.py::readme_add_keyboard_parts
    Given the README
    Then the heading Test my keyboard is inside the Add your keyboard section, after the masking command, the local test command, the validator error and the worked diff

  Scenario: Every profile has a README row that says whether it is tested
    # Still passes if: the table gains a column
    # test: tests/test_repo.py::readme_row_per_profile
    Given each profile in profiles/
    Then the README table has a row with its display name
    And the row says tested exactly when the profile has a verified block
    And the POP Icon Keys row scopes the claim to the key mapping and the MX Keys for Mac row says untested

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
    And neither the README nor any fixture contains the phrase "Linux OS mode" or "Linux mode", compared case-insensitively
    And the only files that may contain it are an explicit allowlist (the plans, the ADRs, the specs, the project rules and the test itself)

  Scenario: The README says to start Solaar hidden and not to close its window
    # Still passes if: the explanation is reworded
    # test: tests/test_repo.py::readme_start_solaar
    Given the README
    Then within the paragraph that names the widget's Start Solaar button it says that closing Solaar's window quits Solaar on Omarchy and stops key routing, gives the command solaar --window=hide, says to leave Solaar running and names the shortcut t
    And the flag in that command is accepted by the installed solaar --help and is the one the setup script uses for autostart
    And on CI, where Solaar is not installed, the --help comparison is skipped with a printed note, and on the development machine with LK_REQUIRE_SOLAAR=1 a skip is a failure

  Scenario: The README says a new battery report arrives after fitting batteries and Restore does not force one
    # Still passes if: the explanation is reworded
    # test: tests/test_repo.py::readme_battery
    Given the README
    Then within the paragraph that holds the phrase "last battery report" it says the widget keeps showing it with its age until the keyboard reports again
    And in that paragraph it says a new report arrives soon after fitting batteries and that Restore or Refresh does not force one
    And it labels the battery rules "unverified until live-checked" until the owner's live check 1 is recorded (the test expects the label now; the owner removes label and expectation together)

  Scenario: The README has an experimental OpenLogi section with an install note and no piped installer
    # Still passes if: the AUR package name is cited with a version
    # test: tests/test_repo.py::readme_openlogi
    Given the README
    Then it has a section on OpenLogi that says the support is experimental and read-only, that keys are not mapped, that switching to OpenLogi disables key mapping in this version (the special keys do nothing), and that setup never installs it
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
