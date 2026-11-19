Feature: Setup picks one backend, refuses an unsafe machine and switches with a record

  Scenario Outline: The backend is chosen from the flag, the record, what is installed and what is running
    # Still passes if: the plan lists the files in another order
    # test: tests/test_backend_select.py::selection_matrix, tests/test_setup.sh::"backend selection matrix"
    Given the flag is <flag>, the record says <record>, Solaar is <solaar> and OpenLogi is <openlogi>
    When setup selects a backend
    Then the backend is <backend> because <reason>

    Examples:
      | flag               | record    | solaar                   | openlogi                 | backend  | reason                                           |
      | --backend openlogi | none      | installed and running    | installed and stopped    | openlogi | the flag wins (a switch if a record differs)     |
      | --backend solaar   | openlogi  | installed and stopped    | installed and running    | solaar   | the flag wins and this is a switch               |
      | none               | solaar    | installed and stopped    | installed and running    | solaar   | the record wins; Re-apply never switches         |
      | none               | none      | not installed            | installed                | openlogi | only OpenLogi is installed (experimental, keys not mapped) |
      | none               | none      | installed                | not installed            | solaar   | only Solaar is installed                         |
      | none               | none      | installed and running    | installed and stopped    | solaar   | the running one                                  |
      | none               | none      | installed and stopped    | installed and running    | openlogi | the running one                                  |
      | none               | none      | installed and stopped    | installed and stopped    | solaar   | neither runs, so the default, said in the plan   |
      | none               | none      | not installed            | not installed            | solaar   | installed through omarchy pkg add solaar as today |
      | --backend solaar   | solaar    | installed and running    | installed and stopped    | solaar   | the flag equals the record: not a switch, no switch plan |
      | --backend openlogi | none      | installed and running    | installed and running    | refused, exit 1 | both daemons run and --backend never overrides the refusal |
      | none               | solaar    | installed and running    | installed and running    | refused, exit 1 | both daemons run: the refusal comes before the record |
      | none               | openlogi  | installed                | not installed            | refused, exit 1, nothing changed | the record names OpenLogi, which is no longer installed |

  Scenario: The status helper and setup choose the backend with the same verb
    # Still passes if: the plan lists the files in another order
    # test: tests/test_backend_select.py::select_backend_verb_shared
    Given a record that says openlogi and both daemons running
    When setup and bin/logitech-keys-status both ask select-backend
    Then setup is refused with exit 1 and the status helper exits 0 with the recorded backend and otherRunning set to the other one

  Scenario Outline: Both daemons running is refused and nothing changes
    # Still passes if: the message wording changes
    # test: tests/test_setup.sh::"both running refused"
    Given Solaar and OpenLogi's agent are both running, <record>, and <flag>
    When I run setup
    Then it exits 1 saying two programs own the receiver and to quit one
    And no file is written, no process is stopped or started and no record is created or changed

    Examples:
      | record                  | flag                    |
      | there is no record      | no flag is given        |
      | the record says solaar  | no flag is given        |
      | the record says solaar  | --backend openlogi is given |
      | there is no record      | --backend solaar is given |

  Scenario: Setup never installs OpenLogi
    # Still passes if: the sandbox package stub logs more lines
    # test: tests/test_setup.sh::"openlogi never installed"
    Given OpenLogi is not installed and I run setup with --backend openlogi and --yes
    Then setup exits non-zero saying how to install OpenLogi from the README, installs nothing and changes nothing

  Scenario Outline: The consent plan names the backend and everything it will do
    # Still passes if: the plan lists the files in another order
    # test: tests/test_plan.py::backend_plan_lines, tests/test_setup.sh::"consent plan backend lines"
    Given <situation>
    When the plan is computed
    Then the plan has <lines>

    Examples:
      | situation                                                   | lines                                                                                       |
      | Solaar chosen because it is the only one installed          | the backend Solaar, the reason, no experimental badge, and each key as mapped                |
      | OpenLogi chosen because it is the only one installed        | the backend OpenLogi with the experimental badge and "keys not mapped"                       |
      | OpenLogi chosen                                             | each key as "not mapped in this version" (never the internal code) and the line that OpenLogi's configuration is not changed |
      | a switch to OpenLogi                                        | first the plain line "After this, your special keys will do nothing until a later version maps them." and the alternative "To keep key mapping, use Solaar: omarchy pkg add solaar, then setup --backend solaar." |
      | the OpenLogi backend                                        | no OS mode warning (its OS mode is never read) and the OpenLogi layout warning in the Warnings group |
      | v0.3 pop-icon-keys blocks still in Solaar's files, OpenLogi chosen | the Warnings group lists the leftover and says setup under OpenLogi does not edit Solaar's files |
      | OpenLogi chosen                                             | the warning that OpenLogi's OS layout default may move the keyboard out of MacOS mode and break SUPER + CTRL + Q |
      | a profile key the keyboard does not report                  | that key listed as absent                                                                    |
      | a switch from OpenLogi to Solaar, service enabled           | the daemon actions in order: stop, systemctl --user disable --now openlogi-agent.service with the retake reason, start Solaar |
      | a switch from OpenLogi to Solaar, service already disabled  | stop and start only, and no disable line                                                     |
      | a switch from Solaar to OpenLogi                            | the stop, the removal of the Solaar rules and diversion, the enable and start of the OpenLogi service |
      | any plan                                                    | nothing that setup will not do, and its Warnings group directly above the prompt line            |

  Scenario Outline: Every daemon action in the plan is a mutating call the accepted run makes, in the same order
    # Still passes if: the stub log prints the unit name in another form
    # test: tests/test_setup.sh::"plan daemon lines equal the stub log"
    Given the plan for <command> lists its daemon action lines
    When the same run is accepted with logging stubs for Solaar, pgrep and systemctl
    Then the mutating calls in the stub logs (stop, start, enable, disable) equal the plan's daemon action lines, in the same order
    And read calls (cat, is-active, is-enabled, show) are not counted and no mutating call is made that the plan did not list

    Examples:
      | command                                                                                   |
      | setup --backend openlogi, a switch from a Solaar record (the unit not enabled)            |
      | setup --backend solaar, a switch from an OpenLogi record (the unit enabled, answer y)     |
      | setup on a machine with only Solaar installed                                             |

  Scenario Outline: The pure switch function lists the steps and, on a resume, only the remaining ones
    # Still passes if: the step ids are renamed consistently
    # test: tests/test_switch.py::switch_steps_lists, tests/test_switch.py::switch_resume_points
    Given a record with backend <from> and <marker>, and the OpenLogi service <service>
    When switch_steps is asked for the switch to <to>
    Then the step ids are <steps>

    Examples:
      | from     | marker                                                      | service         | to       | steps                                                                              |
      | solaar   | no switching marker                                         | not enabled     | openlogi | begin, stop-old, remove-old, enable-new, start-new, apply-new, finish             |
      | solaar   | no switching marker                                         | already enabled | openlogi | begin, stop-old, remove-old, start-new, apply-new, finish                          |
      | openlogi | no switching marker                                         | enabled         | solaar   | begin, stop-old, remove-old, disable-old-service, start-new, apply-new, finish     |
      | openlogi | no switching marker                                         | already disabled | solaar  | begin, stop-old, remove-old, start-new, apply-new, finish                          |
      | solaar   | switching solaar to openlogi, the old daemon already stopped | not enabled     | openlogi | remove-old, enable-new, start-new, apply-new, finish (a resume)                   |
      | solaar   | switching solaar to openlogi, the old artifacts already removed | not enabled  | openlogi | enable-new, start-new, apply-new, finish (a resume)                               |
      | solaar   | switching solaar to openlogi, the new daemon already running | enabled         | openlogi | apply-new, finish (a resume)                                                       |
      | openlogi | switching openlogi to solaar, the service already disabled   | disabled        | solaar   | start-new, apply-new, finish (a resume)                                            |
      | solaar   | switching openlogi to solaar (a different pair than asked)   | any             | openlogi | refused with a message naming both pairs, no steps                                 |

  Scenario: A switch from Solaar to OpenLogi and back leaves Solaar's files as they were
    # Still passes if: the backup file names differ
    # test: tests/test_setup.sh::"switch round trip"
    Given setup applied Solaar and the sandbox files are checksummed
    When I run setup --backend openlogi and accept, then setup --backend solaar and accept
    Then the Solaar files are byte-identical to the first Solaar run apart from backups
    And the systemctl and Solaar stub logs show stop, then start of the new daemon, in that order, for each switch
    And OpenLogi's configuration is unchanged by both switches

  Scenario: The record is written before the switch and cleared after it
    # Still passes if: the other record fields are reordered
    # test: tests/test_setup.sh::"write-ahead switching record"
    Given a recorded Solaar install
    When I run setup --backend openlogi and accept
    Then the record has switching from solaar to openlogi before the old daemon is stopped
    And after the switch the record says backend openlogi and switching null

  Scenario: A switch interrupted when the new daemon fails to start restores the old one and can be finished
    # Still passes if: the retry wait is shortened
    # test: tests/test_setup.sh::"switch interrupted at the agent start"
    Given the systemctl stub makes the start of the OpenLogi unit fail
    When I run setup --backend openlogi and accept
    Then Solaar is started again, switching stays set and the exit code is non-zero with a message to re-run
    And running setup --backend openlogi again after the stub is fixed completes the switch and clears switching

  Scenario: A switch stopped by a signal restarts the old daemon
    # Still passes if: the signal arrives a little earlier
    # test: tests/test_setup.sh::"switch stopped by SIGTERM"
    Given a switch is waiting for the old daemon to stop
    When setup receives SIGTERM
    Then the old daemon is started again and the record still says switching

  Scenario Outline: Enable and disable only what the plugin enabled
    # Still passes if: the stub log lists the unit file name in another form
    # test: tests/test_setup.sh::"enable and disable ownership"
    Given the OpenLogi unit is <initial> when I switch to OpenLogi and later uninstall
    Then the stub log shows <enable>, and uninstall shows <disable>, and the record says enabledService <recorded>

    Examples:
      | initial               | enable                         | disable                         | recorded |
      | not enabled           | one enable then start          | one disable                     | true     |
      | already enabled       | start only                     | no disable                      | false    |

  Scenario Outline: A switch to Solaar disables OpenLogi's service only with consent and only when it is enabled
    # Still passes if: the stub log prints the unit name in another form
    # test: tests/test_setup.sh::"disable on switch to solaar"
    Given the record says backend openlogi, the OpenLogi agent is running, the OpenLogi unit in the stub is <unit> and I run setup --backend solaar and answer <answer>
    Then the stub log shows <calls>
    And the record says disabledService <recorded>

    Examples:
      | unit     | answer | calls                                                                                                            | recorded |
      | enabled  | y      | stop, then disable --now, then Solaar started, in that order                                                     | true     |
      | enabled  | n      | no mutating call at all (no stop, start, enable or disable); read calls (cat, is-active, is-enabled) may appear; no file changed, exit 0 | false |
      | disabled | y      | no disable call, and the plan had no disable line                                                                | false    |

  Scenario: A switch to OpenLogi never disables the service
    # Still passes if: the sandbox unit file name differs
    # test: tests/test_setup.sh::"no disable on switch to openlogi"
    Given the record says backend solaar, Solaar is running, the OpenLogi unit in the stub is enabled and I run setup --backend openlogi and answer y
    Then no disable call appears anywhere in the stub log
    And the record says disabledService false

  Scenario: Applying during a switch keeps the switching marker and the service flags
    # Still passes if: the record lists the profiles in another order
    # test: tests/test_setup.sh::"apply merges into the switching record", tests/test_state.py::applied_field_writes
    Given a switch to OpenLogi has begun, so the record has switching, and the service flag is then written
    When the new backend's apply runs
    Then the record still has switching and the flags it had, and the applied profiles are updated (apply merged)
    And only the final step clears switching

  Scenario: A failure after the disable restarts the OpenLogi agent and the switch can be finished
    # Still passes if: the retry message is reworded
    # test: tests/test_setup.sh::"switch to solaar interrupted after disable"
    Given the OpenLogi unit is enabled and the Solaar start stub fails
    When I run setup --backend solaar and answer y
    Then the stub log shows the OpenLogi unit started again with start (and not enabled again), switching stays set and the exit is non-zero with a message to re-run
    And running setup --backend solaar again after the stub is fixed finishes the switch and records disabledService true

  Scenario Outline: Uninstall removes every recorded backend's artifacts
    # Still passes if: the backups are left in place
    # test: tests/test_setup.sh::"uninstall across backends"
    Given an install whose record is <state>
    When I run uninstall and accept
    Then <result>

    Examples:
      | state                                              | result                                                                                              |
      | backend solaar                                     | the Solaar artifacts, the Hyprland blocks, the state directory and the helpers are gone              |
      | backend openlogi                                   | the Hyprland blocks, the state directory and the helpers are gone and OpenLogi's config is unchanged |
      | switching from solaar to openlogi (interrupted)    | both backends' artifacts are removed, Solaar's diversion is reset and the record is deleted          |
      | switching with the old daemon already stopped      | its files are edited while it is stopped, it is not started afterwards and the message says so       |
      | any                                                | user content in every file is byte-identical to before setup                                         |

  Scenario Outline: Uninstall restarts only the daemon it stopped
    # Still passes if: the backups are left in place
    # test: tests/test_setup.sh::"uninstall restarts only what it stopped"
    Given an install whose record says backend <backend> and its daemon is <state> when uninstall starts
    When I run uninstall and accept
    Then the daemon is <after> and the stub logs show <calls>

    Examples:
      | backend  | state    | after                                      | calls                                                  |
      | solaar   | running  | running again (it was stopped for the edit) | a stop then a start of Solaar                          |
      | solaar   | stopped  | still stopped                              | no start call                                          |
      | openlogi | stopped  | still stopped                              | no stop and no start call (nothing of OpenLogi's is edited) |
      | openlogi | running  | still running                              | no stop and no start call                              |

  Scenario: A v0.3 leftover under an OpenLogi setup is warned about and never edited
    # Still passes if: the leftover is in the rules or the bindings file
    # test: tests/test_plan.py::legacy_leftover_openlogi_warning, tests/test_setup.sh::"legacy leftover under openlogi"
    Given Solaar's rules file still holds v0.3 pop-icon-keys blocks and the machine switches to OpenLogi
    When I run setup --backend openlogi and accept
    Then the plan's Warnings group lists the leftover and says setup under OpenLogi does not edit Solaar's files
    And Solaar's files are byte-identical afterwards, and a later uninstall still removes both generations

  Scenario: Uninstall never uninstalls a package or re-enables the other backend
    # Still passes if: the printed hint's wording changes
    # test: tests/test_setup.sh::"uninstall hints only"
    Given an install that was switched from OpenLogi to Solaar and the record says disabledService true
    When I run uninstall and accept
    Then no package command is run and no enable call is made
    And the message prints the command that would re-enable OpenLogi's service if the user wants it

  Scenario Outline: OpenLogi's files change only as the consented step says
    # Still passes if: the sandbox folder name differs
    # test: tests/test_setup.sh::"openlogi files untouched"
    Given the sandbox OpenLogi config.toml and systemd user folder are checksummed
    When <action> runs
    Then <result>

    Examples:
      | action                                                    | result                                                                                          |
      | setup under the Solaar backend                            | both checksums are identical                                                                     |
      | status                                                    | both checksums are identical                                                                     |
      | restore                                                   | both checksums are identical                                                                     |
      | uninstall of a Solaar record                              | both checksums are identical                                                                     |
      | a switch to OpenLogi with the unit not enabled            | config.toml is identical and the systemd user folder differs by exactly one added entry (the enable symlink) |
      | a switch to Solaar with the unit enabled, answer y        | config.toml is identical and exactly one entry is removed from the systemd user folder (the unit disabled)  |
