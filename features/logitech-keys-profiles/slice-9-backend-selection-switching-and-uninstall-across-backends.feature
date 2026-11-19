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

  Scenario: Both daemons running is refused and nothing changes
    # Still passes if: the message wording changes
    # test: tests/test_setup.sh::"both running refused"
    Given Solaar and OpenLogi's agent are both running and no flag is given
    When I run setup
    Then it exits 1 saying two programs own the receiver and to quit one
    And no file is written, no process is stopped or started and no record is created

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
      | OpenLogi chosen                                             | each key as "unsupported by OpenLogi (notImplemented)" and the line that OpenLogi's configuration is not changed |
      | OpenLogi chosen                                             | the warning that OpenLogi's OS layout default may move the keyboard out of MacOS mode and break SUPER + CTRL + Q |
      | a profile key the keyboard does not report                  | that key listed as absent                                                                    |
      | a switch from OpenLogi to Solaar, service enabled           | the daemon actions in order: stop, systemctl --user disable --now openlogi-agent.service with the retake reason, start Solaar |
      | a switch from OpenLogi to Solaar, service already disabled  | stop and start only, and no disable line                                                     |
      | a switch from Solaar to OpenLogi                            | the stop, the removal of the Solaar rules and diversion, the enable and start of the OpenLogi service |
      | any plan                                                    | nothing that setup will not do                                                               |

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
    Given the OpenLogi unit in the stub is <unit> and I run <command> and answer <answer>
    Then the stub log shows <calls>
    And the record says disabledService <recorded>

    Examples:
      | unit     | command                  | answer | calls                                                                                         | recorded |
      | enabled  | setup --backend solaar   | y      | stop, then disable --now, then Solaar started, in that order                                  | true     |
      | enabled  | setup --backend solaar   | n      | no systemctl call at all, no file changed, exit 0                                             | false    |
      | disabled | setup --backend solaar   | y      | no disable call, and the plan had no disable line                                             | false    |
      | enabled  | setup --backend openlogi | y      | no disable call anywhere                                                                      | false    |

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

  Scenario: Uninstall never uninstalls a package or re-enables the other backend
    # Still passes if: the printed hint's wording changes
    # test: tests/test_setup.sh::"uninstall hints only"
    Given an install that was switched from OpenLogi to Solaar and the record says disabledService true
    When I run uninstall and accept
    Then no package command is run and no enable call is made
    And the message prints the command that would re-enable OpenLogi's service if the user wants it

  Scenario: Nothing outside the consented steps writes OpenLogi's files
    # Still passes if: the sandbox folder name differs
    # test: tests/test_setup.sh::"openlogi files untouched"
    Given the sandbox OpenLogi config and systemd user folder are checksummed
    When setup, a switch each way, status, restore and uninstall run
    Then both checksums are unchanged except the single consented enable symlink of a switch to OpenLogi and the single consented disable of a switch to Solaar
