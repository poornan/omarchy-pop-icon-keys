Feature: Keyboards are data files checked by one strict reader and matched by one identity module

  Scenario: The shipped profiles are valid and tested only when verified
    # Still passes if: a key's label text reads oddly
    # test: tests/test_profiles.py::shipped_profiles_valid
    Given the profiles folder with the POP Icon Keys and MX Keys for Mac profiles
    When the profile check runs
    Then both profiles pass
    And the POP Icon Keys profile counts as tested because it records where and when it was verified
    And the MX Keys for Mac profile counts as untested because it records no verification

  Scenario: Profiles use Solaar's own key names and ids
    # Still passes if: a label differs from the printed keycap
    # test: tests/test_profiles.py::pop_pairs_and_lock_binding
    Given the POP Icon Keys profile
    Then Show Desktop is 110, MultiPlatform Search is 212, Dictation is 259, Emoji is 264 and Screen Capture is 266
    And its Lock binding is the chord SUPER + CTRL + Q running the lock action

  Scenario: MX Keys for Mac maps exactly four keys to named actions
    # Still passes if: the key order inside the profile changes
    # test: tests/test_profiles.py::mx_mapping_exact
    Given the MX Keys for Mac profile
    Then its control ids are exactly 225, 191, 111 and 10
    And 225 runs the app launcher, 191 the region screenshot, 111 the lock action and 10 the calculator
    And Mission Control (224) and Eject (13) are not listed

  Scenario Outline: A malformed profile is refused and the file and field are named
    # Still passes if: the reason text after the file and field names changes
    # test: tests/test_profiles.py::mutation_matrix
    Given a valid profile changed so that <defect>
    When the profile check runs
    Then it fails naming that profile file and the field at fault

    Examples:
      | defect                                                          |
      | it has a field the schema does not know                         |
      | a key has a field the schema does not know                      |
      | the verified block has a field the schema does not know         |
      | a key carries a command instead of an action                    |
      | a key names an action not in the action table                   |
      | a binding names an action not in the action table               |
      | the schema field is missing                                     |
      | the schema field is 2                                           |
      | the model id is lowercase                                       |
      | the model id has eleven digits                                  |
      | the model id has thirteen digits                                |
      | the list of model ids is empty                                  |
      | the list of names is empty                                      |
      | the list of keys is empty                                       |
      | a key has a name but no control id                              |
      | a key has a control id but no name                              |
      | two keys share a control id                                     |
      | two keys share a name                                           |
      | its model id is also listed by another profile                  |
      | its slug does not match its file name                           |
      | the verified block lacks the OS mode                            |
      | the verified block lacks the Fn-swap flag                       |
      | the verified Fn-swap flag is a string                           |
      | the verified date is not in the form year-month-day             |
      | the verified Solaar version is not a version number             |
      | a label contains a double quote                                 |
      | a label contains a newline                                      |
      | the file is not valid JSON                                      |
      | the top level of the file is a list                             |

  Scenario Outline: A Hyprland chord is accepted only in the fixed form
    # Still passes if: the list of accepted function keys grows
    # test: tests/test_profiles.py::chord_boundary_table
    Given a profile whose binding chord is <chord>
    When the profile check runs
    Then the chord is <verdict>

    Examples:
      | chord                                      | verdict  |
      | SUPER + CTRL + Q                           | accepted |
      | SUPER + F5                                 | accepted |
      | SHIFT + ALT + SUPER + CTRL + A             | accepted |
      | Q alone with no modifier                   | refused  |
      | SUPER + CTRL with no key                   | refused  |
      | SUPER + Q + W with two keys                | refused  |
      | SUPER + SUPER + Q with a repeated modifier | refused  |
      | an empty chord                             | refused  |
      | a chord containing a double quote          | refused  |
      | a chord ending in a newline                | refused  |
      | a chord containing a backslash             | refused  |
      | a chord containing two closing square brackets | refused |
      | super + q in lowercase                     | refused  |
      | SUPER+Q without spaces                     | refused  |
      | SUPER + Q with a trailing space            | refused  |

  Scenario Outline: A malformed action table is refused
    # Still passes if: the action ids are listed in another order
    # test: tests/test_profiles.py::action_table_mutations
    Given the action table changed so that <defect>
    When the profile check runs
    Then it fails naming the action table and the action id at fault

    Examples:
      | defect                                         |
      | an action names a helper the plugin does not ship |
      | an action's argument list holds a number       |
      | an action's argument list is empty             |
      | an action's argument holds a newline           |
      | two actions share an id                        |
      | an action has both an argument list and a helper |

  Scenario: One keyboard's name may not be a substring of another's
    # Still passes if: two profiles share a key name with the same action
    # test: tests/test_profiles.py::substring_name_refused
    Given a second profile named "MX Keys" next to "MX Keys for Mac"
    When the profile check runs
    Then it fails because the name would match both keyboards

  Scenario: Two profiles may not bind one chord to different actions
    # Still passes if: two profiles bind the same chord to the same action
    # test: tests/test_profiles.py::chord_conflict_refused
    Given two profiles that both bind SUPER + CTRL + Q, one to lock and one to the app launcher
    When the profile check runs
    Then it fails naming both profile files

  Scenario Outline: Names and ids are checked against Solaar's own key table
    # Still passes if: the table lists more keys than the profiles use
    # test: tests/test_profiles.py::key_table_cross_check
    Given the key table is <table>
    When the profile check runs
    Then <outcome>

    Examples:
      | table                                                      | outcome                                                                |
      | a supplied table that agrees with every profile            | every profile passes                                                   |
      | a supplied table where one id has another name             | it fails naming the profile, the key and both names                    |
      | the installed Solaar's table                               | every profile passes and the source is reported as Solaar              |
      | the pinned snapshot because Solaar cannot be imported      | every profile passes and the source is reported as the snapshot        |
      | not available at all                                       | the cross-check is skipped with a printed note and nothing else is skipped |
      | not available and LK_REQUIRE_SOLAAR is 1                   | the run fails saying a Solaar check was skipped                        |

  Scenario: A released slug cannot be renamed or dropped
    # Still passes if: a new profile is added
    # test: tests/test_profiles.py::permanent_slugs
    Given the frozen list of shipped slugs
    When a shipped slug has no profile file
    Then the profile check fails naming the slug

  Scenario: A profile without its recorded fixture fails
    # Still passes if: the fixture holds extra devices
    # test: tests/test_profiles.py::fixture_required
    Given a profile with no recorded fixture folder
    When the profile check runs
    Then it fails naming the missing fixture

  Scenario Outline: A fixture must be masked, versioned and honestly labelled
    # Still passes if: the fixture has trailing blank lines
    # test: tests/test_profiles.py::fixture_rules
    Given a recorded fixture where <defect>
    When the fixture check runs
    Then it fails naming the fixture

    Examples:
      | defect                                                          |
      | the first line does not carry the Solaar version                |
      | the Solaar version differs from the profile's verified version  |
      | a serial number is not masked                                   |
      | a unit id is not masked                                         |
      | a MAC address is present                                        |
      | a hid or hidraw device path is present                          |
      | the model id differs from the profile's                         |
      | it is marked synthetic yet its profile has verified             |
      | the verified keyboard's recording has a profile key missing from both diversion lines |

  Scenario: Fixture variants are derived from the profile and match the recorded ones
    # Still passes if: the derived MX Keys for Mac variants are spaced differently
    # test: tests/test_profiles.py::derived_variants, tests/test_fixture_equality.py::derived_equals_recorded
    Given the recorded fixture of a profile
    When the routed, dropped and not-set-up variants are derived
    Then routed has every mapped key diverted in both lines
    And dropped has them diverted when saved and regular live
    And not-set-up has some keys regular when saved
    And for the POP Icon Keys each derived variant equals the variant recorded in v0.3

  Scenario Outline: A Solaar device is matched to a profile by model id, then by exact name
    # Still passes if: the device's battery level differs
    # test: tests/test_profiles.py::identity_matcher
    Given a device with model id <model id> and name <name>
    When the device is matched against the shipped profiles
    Then it matches <profile>

    Examples:
      | model id                       | name                | profile                  |
      | B38F00000000                   | POP Icon Keys       | POP Icon Keys            |
      | B38F00000000                   | a renamed keyboard  | POP Icon Keys            |
      | all zeros                      | POP Icon Keys       | POP Icon Keys            |
      | the name stored as the model id| POP Icon Keys       | POP Icon Keys            |
      | B36140920000                   | MX Keys for Mac     | MX Keys for Mac          |
      | an unknown model id            | MX Keys S           | no profile               |
      | an unknown model id            | MX Keys Mini        | no profile               |
      | B04200000000                   | MX Master 4         | no profile               |

  Scenario: Bluetooth and Bolt entries of one keyboard both match
    # Still passes if: the entries appear in another order in the file
    # test: tests/test_profiles.py::known_two_entries
    Given Solaar's saved settings hold two entries for one keyboard with different names
    When the saved entries are matched
    Then both entries are returned with their line spans

  Scenario: The reader's command line validates and lists profiles
    # Still passes if: the command line prints profiles in another order
    # test: tests/test_profiles.py::cli_validate_list
    Given the profiles folder with the shipped profiles
    When the reader's validate and list commands run
    Then validate exits 0 and list prints one line per profile with its slug, display name and tested flag
    And a broken profiles folder exits 4 naming the file
