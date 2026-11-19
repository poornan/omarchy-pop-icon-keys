Feature: Keyboards are preset files checked by one reader and matched by exact identity

  Scenario: The shipped presets are valid and tested only when verified
    # Still passes if: a key's label wording changes
    # test: tests/test_profiles.py::shipped_valid
    Given the profiles folder with the POP Icon Keys and MX Keys for Mac presets
    When the preset check runs
    Then both pass
    And POP Icon Keys counts as tested because it records where and when it was verified
    And MX Keys for Mac counts as untested because it records no verification and carries a note

  Scenario: POP uses Solaar's own names and ids and the Lock chord
    # Still passes if: a label differs from the printed keycap
    # test: tests/test_profiles.py::pop_pairs_lock
    Given the POP Icon Keys preset
    Then Show Desktop is 110, MultiPlatform Search is 212, Dictation is 259, Emoji is 264 and Screen Capture is 266
    And its Lock binding is the chord SUPER + CTRL + Q running omarchy-system-lock

  Scenario: MX Keys for Mac equals the recorded hardware facts and maps exactly four keys
    # Still passes if: the recording's battery percentage differs
    # test: tests/test_profiles.py::mx_matches_recording
    Given the owner's masked recording of the MX Keys for Mac
    Then the model id is B36140920000 and the names are "MX Keys for Mac" and "MX Keys Mac"
    And the keys are 225 Dashboard Launchpad/Action Center, 191 Screen Capture/Print Screen, 111 Screen Lock and 10 Calculator and no others
    And its OS mode is MacOS, its battery feature is BATTERY STATUS and the recording shows the same Set OS and feature
    And the synthetic MX fixture files are gone and the recorded one is masked

  Scenario Outline: A malformed preset is refused and the file and field are named
    # Still passes if: the reason text after the file and field changes
    # test: tests/test_profiles.py::mutation_matrix
    Given a valid preset changed so that <defect>
    When the preset check runs
    Then it fails naming that file and the field at fault

    Examples:
      | defect                                          |
      | the schema field is missing or is not 1         |
      | the slug differs from the file name             |
      | an unknown top-level field is present           |
      | modelIds, names or keys is empty, or a model id is lowercase hex or 11 digits |
      | a key has no cid or no label, or two keys share a cid or a name |
      | the battery feature is not a known feature      |
      | the verified block has a wrong type             |
      | the note holds a newline                        |
      | the file is not valid JSON or not an object     |
      | a second preset shares a model id or a name     |
      | osMode is missing, Ubuntu, lowercase macos or inside verified |

  Scenario Outline: A command is an argument list of clean strings
    # Still passes if: the helper placeholder is spelled differently in a test preset
    # test: tests/test_profiles.py::command_matrix
    Given a key whose command is <command>
    When the preset check runs
    Then <outcome>

    Examples:
      | command                                         | outcome                              |
      | a plain string                                  | it fails naming the key              |
      | an empty list                                   | it fails naming the key              |
      | a list holding a number                         | it fails naming the key              |
      | a list holding a newline                        | it fails naming the key              |
      | a list holding quotes, brackets, colons and # | it passes (the rules module escapes) |
      | the placeholder @show-desktop first             | it passes                            |
      | an unknown placeholder @other first             | it fails naming the key              |

  Scenario Outline: A binding chord must fully match the fixed pattern
    # Still passes if: the binding label changes
    # test: tests/test_profiles.py::chord_matrix
    Given a binding with the chord <chord>
    When the preset check runs
    Then the chord is <verdict>

    Examples:
      | chord                          | verdict  |
      | SUPER + CTRL + Q               | accepted |
      | SUPER + F5                     | accepted |
      | SHIFT + ALT + SUPER + CTRL + A | accepted |
      | Q alone                        | refused  |
      | SUPER + Q + W                  | refused  |
      | a chord ending in a newline    | refused  |
      | a chord holding a double quote | refused  |
      | a chord holding ]]             | refused  |

  Scenario: A preset without its recorded fixture fails
    # Still passes if: the fixture holds extra devices
    # test: tests/test_profiles.py::fixture_required
    Given a preset with no fixture folder
    When the preset check runs
    Then it fails naming the missing fixture

  Scenario Outline: A fixture must be masked, versioned and honestly labelled
    # Still passes if: the fixture has trailing blank lines
    # test: tests/test_profiles.py::fixture_rules
    Given a recorded fixture where <defect>
    When the fixture check runs
    Then it fails naming the fixture

    Examples:
      | defect                                                         |
      | the first line carries no Solaar version                       |
      | the version differs from the preset's verified version         |
      | a serial number is not masked                                  |
      | a unit id is not masked                                        |
      | a MAC address or a hid path is present                         |
      | the model id differs from the preset's                         |
      | the Set OS line differs from the preset's OS mode              |
      | it is marked synthetic yet its preset has a verified block     |

  Scenario: Fixture variants are derived from the preset and equal the recorded POP ones
    # Still passes if: the derived MX variants are spaced differently
    # test: tests/test_profiles.py::derived_variants
    Given the recorded fixture of a preset
    When the routed, dropped and not-set-up variants are derived
    Then routed has every mapped key diverted in both lines, dropped has them diverted when saved and regular live, and not-set-up has some keys regular when saved
    And for POP each derived variant equals the variant recorded in v0.3

  Scenario Outline: A Solaar device is matched to a preset by model id, then by exact name
    # Still passes if: the device's battery level differs
    # test: tests/test_profiles.py::identity_matcher
    Given a device with model id <model id> and name <name>
    When it is matched against the shipped presets
    Then it matches <preset>

    Examples:
      | model id                     | name                | preset          |
      | B38F00000000                 | a renamed keyboard  | POP Icon Keys   |
      | all zeros                    | POP Icon Keys       | POP Icon Keys   |
      | B36140920000                 | MX Keys for Mac     | MX Keys for Mac |
      | all zeros                    | MX Keys Mac         | MX Keys for Mac |
      | the name stored as model id  | MX Keys Mac         | MX Keys for Mac |
      | an unknown id                | MX Keys Mini        | no preset       |
      | an unknown id                | MX Keys S           | no preset       |
      | an unknown id                | MX Keys             | no preset       |
      | B04200000000                 | MX Master 4         | no preset       |

  Scenario: Bluetooth and Bolt entries of one keyboard both match
    # Still passes if: the entries appear in another order in the file
    # test: tests/test_profiles.py::two_entries
    Given Solaar's saved settings hold two entries for one keyboard under different names
    When the saved entries are matched
    Then both are returned with their line spans

  Scenario: The reader's command line validates and lists presets
    # Still passes if: presets are listed in another order
    # test: tests/test_profiles.py::cli
    Given the shipped presets
    When the validate and list commands run under the isolated interpreter from another working directory
    Then validate exits 0 and list prints one line per preset
    And a broken folder exits 4 naming the file

  Scenario: Key names are cross-checked against the installed Solaar when it can be imported
    # Still passes if: Solaar renames a key the presets do not use
    # test: tests/test_profiles.py::key_table_local
    Given Solaar's key table is importable on the dev machine
    When the optional key-table check runs
    Then every preset name and cid pair agrees with Solaar, and without Solaar the check prints a skip note and CI is unaffected
