Feature: The repository documents and gates what it ships

  Scenario: CI runs the tests with pinned actions and least privilege
    # Still passes if: a job is renamed
    # test: tests/test_repo.py::ci_workflow
    Given .github/workflows/test.yml
    Then every action is pinned by a full commit SHA, permissions are contents: read, and it validates the presets and runs the stdlib and sandbox tests but not the QML ones

  Scenario Outline: The README has each required topic in its own section
    # Still passes if: a sentence is reworded
    # test: tests/test_repo.py::readme_topics
    Given README.md
    Then the section <section> mentions <keywords>

    Examples:
      | section                    | keywords                                                                          |
      | supported keyboards        | POP Icon Keys, MX Keys for Mac, tested, untested, MacOS                           |
      | install and uninstall      | the new repository URL, setup, uninstall, consent                                 |
      | upgrading from v0.3        | the old repository name, delete unmarked old rules by hand, uninstall as rollback |
      | troubleshooting and known issues | closing Solaar's window quits it, solaar --window=hide, Start Solaar, Open Solaar, host-name decoding bug, per-keyboard queries, Status unknown, battery unverified until live-checked, a new report after new batteries |
      | add your keyboard          | solaar show with a name, the preset format, a masking command, recording a fixture, what the PR must contain, a preset can run any command so it is reviewed, Fn-swap, cid naming |

  Scenario: The README order and its claims about the OS mode
    # Still passes if: an extra section is added at the end
    # test: tests/test_repo.py::readme_order
    Given README.md
    Then its sections come in the fixed order, MacOS OS mode is required and never changed by the plugin, and no shipped file says Linux OS mode or Linux mode (allowlist: plan, ADRs, project rules)

  Scenario: The old repository name appears only where it should
    # Still passes if: the upgrade section grows
    # test: tests/test_repo.py::repo_names
    Given the README and the install commands in it
    Then omarchy-pop-icon-keys appears only in the upgrading section

  Scenario: The project rules describe the slim design
    # Still passes if: a rule is reordered
    # test: tests/test_repo.py::claude_rules
    Given .claude/CLAUDE.md
    Then it names presets, D19, the per-device show rule, the MX codename and the debug-flag note, and it no longer mentions an action table, applied.json or a backend
