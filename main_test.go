package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunLinksMatchedDummyFileAndFolder(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := filepath.Join(t.TempDir(), "target with spaces")

	writeTestFile(t, filepath.Join(packageDirectory, "dummy.config"), "dummy config\n")
	writeTestFile(t, filepath.Join(packageDirectory, "folder", "nested.txt"), "nested content\n")
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./*.config", "./folder"},
		Target: map[string]string{
			"macos": targetDirectory,
			"linux": targetDirectory,
		},
	})

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	if err := Run(repository, []string{"macos"}, &stdout, &stderr); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	assertSymlink(t,
		filepath.Join(targetDirectory, "dummy.config"),
		filepath.Join(packageDirectory, "dummy.config"),
	)
	assertSymlink(t,
		filepath.Join(targetDirectory, "folder"),
		filepath.Join(packageDirectory, "folder"),
	)

	nested, err := os.ReadFile(filepath.Join(targetDirectory, "folder", "nested.txt"))
	if err != nil {
		t.Fatalf("read through directory symlink: %v", err)
	}
	if got, want := string(nested), "nested content\n"; got != want {
		t.Fatalf("nested content = %q, want %q", got, want)
	}

	if got := stderr.String(); got != "" {
		t.Fatalf("stderr = %q, want empty", got)
	}
	for _, destination := range []string{
		filepath.Join(targetDirectory, "dummy.config"),
		filepath.Join(targetDirectory, "folder"),
	} {
		if !strings.Contains(stdout.String(), "linked     "+destination) {
			t.Errorf("stdout = %q, want linked line for %s", stdout.String(), destination)
		}
	}
}

func TestRunDryRunReportsLinksWithoutChangingFilesystem(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := filepath.Join(t.TempDir(), "missing", "target")
	source := filepath.Join(packageDirectory, "dummy.config")
	destination := filepath.Join(targetDirectory, "dummy.config")

	writeTestFile(t, source, "dummy\n")
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./dummy.config"},
		Target: map[string]string{"macos": targetDirectory},
	})

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	if err := Run(repository, []string{"--dry-run", "macos"}, &stdout, &stderr); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	if _, err := os.Lstat(destination); !os.IsNotExist(err) {
		t.Fatalf("dry-run destination stat error = %v, want not-exist", err)
	}
	if _, err := os.Stat(targetDirectory); !os.IsNotExist(err) {
		t.Fatalf("dry-run target directory stat error = %v, want not-exist", err)
	}
	if got, want := stdout.String(), "would link "+destination+" -> "+source+"\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if got := stderr.String(); got != "" {
		t.Fatalf("stderr = %q, want empty", got)
	}
}

func TestRunIsIdempotentForCorrectExistingSymlink(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := t.TempDir()
	source := filepath.Join(packageDirectory, "dummy.config")
	destination := filepath.Join(targetDirectory, "dummy.config")

	writeTestFile(t, source, "dummy\n")
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./dummy.config"},
		Target: map[string]string{"macos": targetDirectory},
	})
	if err := os.Symlink(source, destination); err != nil {
		t.Fatalf("create existing symlink: %v", err)
	}

	var stdout bytes.Buffer
	if err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got, want := stdout.String(), "exists     "+destination+" -> "+source+"\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunRefusesDestinationCollisionsBeforeMakingChanges(t *testing.T) {
	tests := []struct {
		name       string
		makeTarget func(t *testing.T, destination string)
	}{
		{
			name: "regular file",
			makeTarget: func(t *testing.T, destination string) {
				writeTestFile(t, destination, "keep me\n")
			},
		},
		{
			name: "directory",
			makeTarget: func(t *testing.T, destination string) {
				t.Helper()
				if err := os.MkdirAll(destination, 0o755); err != nil {
					t.Fatalf("create destination directory: %v", err)
				}
			},
		},
		{
			name: "wrong symlink",
			makeTarget: func(t *testing.T, destination string) {
				t.Helper()
				wrong := filepath.Join(t.TempDir(), "wrong.config")
				writeTestFile(t, wrong, "wrong\n")
				if err := os.Symlink(wrong, destination); err != nil {
					t.Fatalf("create wrong symlink: %v", err)
				}
			},
		},
		{
			name: "broken symlink",
			makeTarget: func(t *testing.T, destination string) {
				t.Helper()
				if err := os.Symlink(filepath.Join(t.TempDir(), "missing"), destination); err != nil {
					t.Fatalf("create broken symlink: %v", err)
				}
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			packageDirectory := filepath.Join(repository, "home", "dummy")
			targetDirectory := t.TempDir()
			firstSource := filepath.Join(packageDirectory, "a.config")
			conflictingSource := filepath.Join(packageDirectory, "z.config")
			firstDestination := filepath.Join(targetDirectory, "a.config")
			conflictingDestination := filepath.Join(targetDirectory, "z.config")

			writeTestFile(t, firstSource, "first\n")
			writeTestFile(t, conflictingSource, "conflict\n")
			writeTestManifest(t, packageDirectory, testManifest{
				Source: []string{"./*.config"},
				Target: map[string]string{"macos": targetDirectory},
			})
			test.makeTarget(t, conflictingDestination)

			var stdout bytes.Buffer
			err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
			if err == nil {
				t.Fatal("Run() error = nil, want destination collision")
			}
			if !strings.Contains(err.Error(), conflictingDestination) {
				t.Fatalf("Run() error = %q, want destination path", err)
			}
			if _, err := os.Lstat(firstDestination); !os.IsNotExist(err) {
				t.Fatalf("first destination was changed before validation completed: %v", err)
			}
			if got := stdout.String(); got != "" {
				t.Fatalf("stdout = %q, want empty", got)
			}
		})
	}
}

func TestRunSelectsOnlyRequestedOperatingSystemTarget(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	macOSTarget := filepath.Join(t.TempDir(), "macos")
	linuxTarget := filepath.Join(t.TempDir(), "linux")
	source := filepath.Join(packageDirectory, "dummy.config")

	writeTestFile(t, source, "dummy\n")
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./dummy.config"},
		Target: map[string]string{
			"macos": macOSTarget,
			"linux": linuxTarget,
		},
	})

	if err := Run(repository, []string{"linux"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	assertSymlink(t, filepath.Join(linuxTarget, "dummy.config"), source)
	if _, err := os.Lstat(filepath.Join(macOSTarget, "dummy.config")); !os.IsNotExist(err) {
		t.Fatalf("macOS destination stat error = %v, want not-exist", err)
	}
}

func TestRunExpandsHomeTarget(t *testing.T) {
	tests := []struct {
		name        string
		target      string
		destination func(home string) string
	}{
		{
			name:   "home itself",
			target: "~",
			destination: func(home string) string {
				return filepath.Join(home, "dummy.config")
			},
		},
		{
			name:   "path below home",
			target: "~/target",
			destination: func(home string) string {
				return filepath.Join(home, "target", "dummy.config")
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			packageDirectory := filepath.Join(repository, "home", "dummy")
			fakeHome := t.TempDir()
			t.Setenv("HOME", fakeHome)

			writeTestFile(t, filepath.Join(packageDirectory, "dummy.config"), "dummy\n")
			writeTestManifest(t, packageDirectory, testManifest{
				Source: []string{"./dummy.config"},
				Target: map[string]string{"macos": test.target},
			})

			var stdout bytes.Buffer
			if err := Run(repository, []string{"--dry-run", "macos"}, &stdout, &bytes.Buffer{}); err != nil {
				t.Fatalf("Run() error = %v", err)
			}
			wantDestination := test.destination(fakeHome)
			if !strings.Contains(stdout.String(), "would link "+wantDestination+" -> ") {
				t.Fatalf("stdout = %q, want expanded destination %s", stdout.String(), wantDestination)
			}
		})
	}
}

func TestRunAbsoluteTargetDoesNotRequireHomeEnvironment(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := t.TempDir()
	t.Setenv("HOME", "")

	writeTestFile(t, filepath.Join(packageDirectory, "dummy.config"), "dummy\n")
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./dummy.config"},
		Target: map[string]string{"macos": targetDirectory},
	})

	if err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v, want nil for absolute target", err)
	}
}

func TestRunRejectsInvalidArgumentsBeforeReadingRepository(t *testing.T) {
	tests := []struct {
		name    string
		args    []string
		wantErr string
	}{
		{name: "missing operating system", args: nil, wantErr: "usage"},
		{name: "extra argument", args: []string{"macos", "extra"}, wantErr: "usage"},
		{name: "unsupported operating system", args: []string{"windows"}, wantErr: "unsupported operating system"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := Run(t.TempDir(), test.args, &bytes.Buffer{}, &bytes.Buffer{})
			if err == nil || !strings.Contains(err.Error(), test.wantErr) {
				t.Fatalf("Run() error = %v, want containing %q", err, test.wantErr)
			}
		})
	}
}

func TestRunReportsUnknownFlagToStderr(t *testing.T) {
	var stderr bytes.Buffer
	err := Run(t.TempDir(), []string{"--unknown", "macos"}, &bytes.Buffer{}, &stderr)
	if err == nil {
		t.Fatal("Run() error = nil, want flag error")
	}
	if !strings.Contains(stderr.String(), "flag provided but not defined") {
		t.Fatalf("stderr = %q, want unknown-flag message", stderr.String())
	}
}

func TestRunHelpDoesNotReadOrModifyRepository(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	err := Run(t.TempDir(), []string{"--help"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("Run() error = %v, want nil", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
	if !strings.Contains(stderr.String(), "usage: dotfiles") {
		t.Fatalf("stderr = %q, want usage", stderr.String())
	}
}

func TestRunRejectsRepositoryWithoutManifests(t *testing.T) {
	err := Run(t.TempDir(), []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "no manage.json") {
		t.Fatalf("Run() error = %v, want missing-manifest error", err)
	}
}

func TestRunReportsBrokenPackageDirectoryInsteadOfSkippingIt(t *testing.T) {
	repository := t.TempDir()
	homeDirectory := filepath.Join(repository, "home")
	targetDirectory := t.TempDir()

	validPackage := filepath.Join(homeDirectory, "valid")
	writeTestFile(t, filepath.Join(validPackage, "config"), "valid\n")
	writeTestManifest(t, validPackage, testManifest{
		Source: []string{"./config"},
		Target: map[string]string{"macos": targetDirectory},
	})
	if err := os.Symlink(filepath.Join(repository, "missing-package"), filepath.Join(homeDirectory, "broken")); err != nil {
		t.Fatalf("create broken package directory: %v", err)
	}

	var stdout bytes.Buffer
	err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "broken") {
		t.Fatalf("Run() error = %v, want broken-package error", err)
	}
	if _, err := os.Lstat(filepath.Join(targetDirectory, "config")); !os.IsNotExist(err) {
		t.Fatalf("valid package was applied while another package was unreadable: %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
}

func TestRunRejectsInvalidManifests(t *testing.T) {
	tests := []struct {
		name     string
		manifest func(target string) string
		wantErr  string
	}{
		{
			name:     "malformed JSON",
			manifest: func(string) string { return "{" },
			wantErr:  "invalid JSON",
		},
		{
			name:     "empty document",
			manifest: func(string) string { return "" },
			wantErr:  "invalid JSON",
		},
		{
			name: "unknown field",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"source":["./dummy.config"],"target":{"macos":%q},"typo":true}`, target)
			},
			wantErr: "invalid JSON",
		},
		{
			name: "trailing JSON value",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"source":["./dummy.config"],"target":{"macos":%q}} {}`, target)
			},
			wantErr: "invalid JSON",
		},
		{
			name: "missing source",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"target":{"macos":%q}}`, target)
			},
			wantErr: "source must contain",
		},
		{
			name: "null source",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"source":null,"target":{"macos":%q}}`, target)
			},
			wantErr: "source must contain",
		},
		{
			name: "source is not an array",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"source":"./dummy.config","target":{"macos":%q}}`, target)
			},
			wantErr: "invalid JSON",
		},
		{
			name: "source contains non-string",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"source":[42],"target":{"macos":%q}}`, target)
			},
			wantErr: "invalid JSON",
		},
		{
			name: "empty source",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"source":[],"target":{"macos":%q}}`, target)
			},
			wantErr: "source must contain",
		},
		{
			name:     "missing target",
			manifest: func(string) string { return `{"source":["./dummy.config"]}` },
			wantErr:  "target must contain",
		},
		{
			name:     "null target",
			manifest: func(string) string { return `{"source":["./dummy.config"],"target":null}` },
			wantErr:  "target must contain",
		},
		{
			name:     "target is not an object",
			manifest: func(string) string { return `{"source":["./dummy.config"],"target":"/tmp"}` },
			wantErr:  "invalid JSON",
		},
		{
			name:     "target contains non-string",
			manifest: func(string) string { return `{"source":["./dummy.config"],"target":{"macos":42}}` },
			wantErr:  "invalid JSON",
		},
		{
			name:     "missing platform target",
			manifest: func(string) string { return `{"source":["./dummy.config"],"target":{"linux":"/tmp"}}` },
			wantErr:  "no target configured for macos",
		},
		{
			name:     "empty platform target",
			manifest: func(string) string { return `{"source":["./dummy.config"],"target":{"macos":""}}` },
			wantErr:  "no target configured for macos",
		},
		{
			name:     "relative target",
			manifest: func(string) string { return `{"source":["./dummy.config"],"target":{"macos":"relative/path"}}` },
			wantErr:  "target must start with ~ or /",
		},
		{
			name:     "named user home target",
			manifest: func(string) string { return `{"source":["./dummy.config"],"target":{"macos":"~someone/config"}}` },
			wantErr:  "~user paths are not supported",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			packageDirectory := filepath.Join(repository, "home", "dummy")
			writeTestFile(t, filepath.Join(packageDirectory, "dummy.config"), "dummy\n")
			writeTestFile(t, filepath.Join(packageDirectory, "manage.json"), test.manifest(t.TempDir()))

			err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
			if err == nil || !strings.Contains(err.Error(), test.wantErr) {
				t.Fatalf("Run() error = %v, want containing %q", err, test.wantErr)
			}
		})
	}
}

func TestRunRejectsInvalidSourcePatterns(t *testing.T) {
	tests := []struct {
		name    string
		pattern func(repository string) string
		wantErr string
	}{
		{
			name:    "empty pattern",
			pattern: func(string) string { return "" },
			wantErr: "source pattern must remain inside its package",
		},
		{
			name:    "absolute pattern",
			pattern: func(repository string) string { return filepath.Join(repository, "outside") },
			wantErr: "source pattern must remain inside its package",
		},
		{
			name:    "parent traversal",
			pattern: func(string) string { return "../outside" },
			wantErr: "source pattern must remain inside its package",
		},
		{
			name:    "malformed glob",
			pattern: func(string) string { return "[" },
			wantErr: "invalid source pattern",
		},
		{
			name:    "unmatched glob",
			pattern: func(string) string { return "./missing-*" },
			wantErr: "matched nothing",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			packageDirectory := filepath.Join(repository, "home", "dummy")
			writeTestFile(t, filepath.Join(packageDirectory, "dummy.config"), "dummy\n")
			writeTestManifest(t, packageDirectory, testManifest{
				Source: []string{test.pattern(repository)},
				Target: map[string]string{"macos": t.TempDir()},
			})

			err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
			if err == nil || !strings.Contains(err.Error(), test.wantErr) {
				t.Fatalf("Run() error = %v, want containing %q", err, test.wantErr)
			}
		})
	}
}

func TestRunRejectsSourceSymlinkThatEscapesPackage(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	externalSource := filepath.Join(t.TempDir(), "external.config")
	linkedSource := filepath.Join(packageDirectory, "external.config")

	writeTestFile(t, externalSource, "external\n")
	if err := os.MkdirAll(packageDirectory, 0o755); err != nil {
		t.Fatalf("create package directory: %v", err)
	}
	if err := os.Symlink(externalSource, linkedSource); err != nil {
		t.Fatalf("create escaping source symlink: %v", err)
	}
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./external.config"},
		Target: map[string]string{"macos": t.TempDir()},
	})

	err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "source escapes its package") {
		t.Fatalf("Run() error = %v, want package-escape error", err)
	}
}

func TestRunRejectsBrokenSourceSymlink(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	brokenSource := filepath.Join(packageDirectory, "broken.config")

	if err := os.MkdirAll(packageDirectory, 0o755); err != nil {
		t.Fatalf("create package directory: %v", err)
	}
	if err := os.Symlink(filepath.Join(t.TempDir(), "missing"), brokenSource); err != nil {
		t.Fatalf("create broken source symlink: %v", err)
	}
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./broken.config"},
		Target: map[string]string{"macos": t.TempDir()},
	})

	err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "resolve source") {
		t.Fatalf("Run() error = %v, want broken-source error", err)
	}
}

func TestRunRejectsHomeTargetWhenHomeIsUnavailable(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	t.Setenv("HOME", "")

	writeTestFile(t, filepath.Join(packageDirectory, "dummy.config"), "dummy\n")
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./dummy.config"},
		Target: map[string]string{"macos": "~"},
	})

	err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "HOME") {
		t.Fatalf("Run() error = %v, want unavailable-home error", err)
	}
}

func TestRunValidatesUnusableTargetBeforeMakingChanges(t *testing.T) {
	repository := t.TempDir()
	targetRoot := t.TempDir()
	goodTarget := filepath.Join(targetRoot, "a-good")
	blockedParent := filepath.Join(targetRoot, "z-blocked")
	blockedTarget := filepath.Join(blockedParent, "nested")

	firstPackage := filepath.Join(repository, "home", "first")
	writeTestFile(t, filepath.Join(firstPackage, "first.config"), "first\n")
	writeTestManifest(t, firstPackage, testManifest{
		Source: []string{"./first.config"},
		Target: map[string]string{"macos": goodTarget},
	})

	secondPackage := filepath.Join(repository, "home", "second")
	writeTestFile(t, filepath.Join(secondPackage, "second.config"), "second\n")
	writeTestManifest(t, secondPackage, testManifest{
		Source: []string{"./second.config"},
		Target: map[string]string{"macos": blockedTarget},
	})
	writeTestFile(t, blockedParent, "not a directory\n")

	err := Run(repository, []string{"macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil {
		t.Fatal("Run() error = nil, want unusable-target error")
	}
	if _, err := os.Lstat(filepath.Join(goodTarget, "first.config")); !os.IsNotExist(err) {
		t.Fatalf("good destination changed before validation completed: %v", err)
	}
}

func TestRunDeduplicatesOverlappingSourcePatterns(t *testing.T) {
	repository := t.TempDir()
	packageDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := t.TempDir()
	source := filepath.Join(packageDirectory, "dummy.config")
	destination := filepath.Join(targetDirectory, "dummy.config")

	writeTestFile(t, source, "dummy\n")
	writeTestManifest(t, packageDirectory, testManifest{
		Source: []string{"./dummy.config", "./*.config"},
		Target: map[string]string{"macos": targetDirectory},
	})

	var stdout bytes.Buffer
	if err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	assertSymlink(t, destination, source)
	if got, want := strings.Count(stdout.String(), destination), 1; got != want {
		t.Fatalf("destination appears %d times in stdout, want %d: %q", got, want, stdout.String())
	}
}

func TestRunRejectsDifferentSourcesClaimingSameDestination(t *testing.T) {
	tests := []struct {
		name  string
		setup func(t *testing.T, repository, targetDirectory string)
	}{
		{
			name: "within one package",
			setup: func(t *testing.T, repository, targetDirectory string) {
				packageDirectory := filepath.Join(repository, "home", "dummy")
				writeTestFile(t, filepath.Join(packageDirectory, "one", "config"), "one\n")
				writeTestFile(t, filepath.Join(packageDirectory, "two", "config"), "two\n")
				writeTestManifest(t, packageDirectory, testManifest{
					Source: []string{"./one/config", "./two/config"},
					Target: map[string]string{"macos": targetDirectory},
				})
			},
		},
		{
			name: "across packages",
			setup: func(t *testing.T, repository, targetDirectory string) {
				for _, packageName := range []string{"first", "second"} {
					packageDirectory := filepath.Join(repository, "home", packageName)
					writeTestFile(t, filepath.Join(packageDirectory, "config"), packageName+"\n")
					writeTestManifest(t, packageDirectory, testManifest{
						Source: []string{"./config"},
						Target: map[string]string{"macos": targetDirectory},
					})
				}
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			targetDirectory := t.TempDir()
			test.setup(t, repository, targetDirectory)

			var stdout bytes.Buffer
			err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
			if err == nil || !strings.Contains(err.Error(), "claimed by both") {
				t.Fatalf("Run() error = %v, want destination-claim error", err)
			}
			if _, err := os.Lstat(filepath.Join(targetDirectory, "config")); !os.IsNotExist(err) {
				t.Fatalf("destination stat error = %v, want not-exist", err)
			}
			if got := stdout.String(); got != "" {
				t.Fatalf("stdout = %q, want empty", got)
			}
		})
	}
}

func TestRunRejectsDestinationNestedUnderAnotherPlannedLink(t *testing.T) {
	repository := t.TempDir()
	targetRoot := t.TempDir()

	nvimPackage := filepath.Join(repository, "home", "neovim")
	nvimSource := filepath.Join(nvimPackage, "nvim")
	writeTestFile(t, filepath.Join(nvimSource, "init.lua"), "-- init\n")
	writeTestManifest(t, nvimPackage, testManifest{
		Source: []string{"./nvim"},
		Target: map[string]string{"macos": targetRoot},
	})

	pluginPackage := filepath.Join(repository, "home", "plugin")
	writeTestFile(t, filepath.Join(pluginPackage, "plugin"), "plugin\n")
	writeTestManifest(t, pluginPackage, testManifest{
		Source: []string{"./plugin"},
		Target: map[string]string{"macos": filepath.Join(targetRoot, "nvim")},
	})

	var stdout bytes.Buffer
	err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "nested") {
		t.Fatalf("Run() error = %v, want nested-destination error", err)
	}
	if _, err := os.Lstat(filepath.Join(targetRoot, "nvim")); !os.IsNotExist(err) {
		t.Fatalf("parent destination changed before validation completed: %v", err)
	}
	if _, err := os.Lstat(filepath.Join(nvimSource, "plugin")); !os.IsNotExist(err) {
		t.Fatalf("nested link was created inside managed source: %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
}

func TestRunRejectsDifferentSourcesClaimingTargetDirectoryAliases(t *testing.T) {
	repository := t.TempDir()
	targetRoot := t.TempDir()
	realTarget := filepath.Join(targetRoot, "real")
	aliasTarget := filepath.Join(targetRoot, "alias")
	if err := os.Mkdir(realTarget, 0o755); err != nil {
		t.Fatalf("create real target: %v", err)
	}
	if err := os.Symlink(realTarget, aliasTarget); err != nil {
		t.Fatalf("create target alias: %v", err)
	}

	firstPackage := filepath.Join(repository, "home", "first")
	writeTestFile(t, filepath.Join(firstPackage, "config"), "first\n")
	writeTestManifest(t, firstPackage, testManifest{
		Source: []string{"./config"},
		Target: map[string]string{"macos": realTarget},
	})

	secondPackage := filepath.Join(repository, "home", "second")
	writeTestFile(t, filepath.Join(secondPackage, "config"), "second\n")
	writeTestManifest(t, secondPackage, testManifest{
		Source: []string{"./config"},
		Target: map[string]string{"macos": aliasTarget},
	})

	var stdout bytes.Buffer
	err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "claimed by both") {
		t.Fatalf("Run() error = %v, want destination-claim error", err)
	}
	if _, err := os.Lstat(filepath.Join(realTarget, "config")); !os.IsNotExist(err) {
		t.Fatalf("destination changed before validation completed: %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
}

func TestRunRejectsDanglingTargetAncestorBeforeMakingChanges(t *testing.T) {
	repository := t.TempDir()
	targetRoot := t.TempDir()
	goodTarget := filepath.Join(targetRoot, "a-good")
	danglingAncestor := filepath.Join(targetRoot, "z-dangling")
	if err := os.Symlink(filepath.Join(targetRoot, "missing"), danglingAncestor); err != nil {
		t.Fatalf("create dangling target ancestor: %v", err)
	}

	firstPackage := filepath.Join(repository, "home", "first")
	writeTestFile(t, filepath.Join(firstPackage, "first.config"), "first\n")
	writeTestManifest(t, firstPackage, testManifest{
		Source: []string{"./first.config"},
		Target: map[string]string{"macos": goodTarget},
	})

	secondPackage := filepath.Join(repository, "home", "second")
	writeTestFile(t, filepath.Join(secondPackage, "second.config"), "second\n")
	writeTestManifest(t, secondPackage, testManifest{
		Source: []string{"./second.config"},
		Target: map[string]string{"macos": filepath.Join(danglingAncestor, "nested")},
	})

	var stdout bytes.Buffer
	err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "resolve target directory") {
		t.Fatalf("Run() error = %v, want dangling-target-ancestor error", err)
	}
	if _, err := os.Lstat(filepath.Join(goodTarget, "first.config")); !os.IsNotExist(err) {
		t.Fatalf("good destination changed before validation completed: %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
}

func TestRunRejectsCanonicalNestedDestinationsRegardlessOfAliasSortOrder(t *testing.T) {
	repository := t.TempDir()
	targetRoot := t.TempDir()
	realTarget := filepath.Join(targetRoot, "a-real")
	aliasTarget := filepath.Join(targetRoot, "z-alias")
	if err := os.Mkdir(realTarget, 0o755); err != nil {
		t.Fatalf("create real target: %v", err)
	}
	if err := os.Symlink(realTarget, aliasTarget); err != nil {
		t.Fatalf("create target alias: %v", err)
	}

	nvimPackage := filepath.Join(repository, "home", "neovim")
	writeTestFile(t, filepath.Join(nvimPackage, "nvim", "init.lua"), "-- init\n")
	writeTestManifest(t, nvimPackage, testManifest{
		Source: []string{"./nvim"},
		Target: map[string]string{"macos": aliasTarget},
	})

	pluginPackage := filepath.Join(repository, "home", "plugin")
	writeTestFile(t, filepath.Join(pluginPackage, "plugin"), "plugin\n")
	writeTestManifest(t, pluginPackage, testManifest{
		Source: []string{"./plugin"},
		Target: map[string]string{"macos": filepath.Join(realTarget, "nvim")},
	})

	var stdout bytes.Buffer
	err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "nested") {
		t.Fatalf("Run() error = %v, want nested-destination error", err)
	}
	if _, err := os.Lstat(filepath.Join(realTarget, "nvim")); !os.IsNotExist(err) {
		t.Fatalf("target changed before validation completed: %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
}

type testManifest struct {
	Source []string          `json:"source"`
	Target map[string]string `json:"target"`
}

func writeTestManifest(t *testing.T, packageDirectory string, manifest testManifest) {
	t.Helper()

	contents, err := json.Marshal(manifest)
	if err != nil {
		t.Fatalf("marshal manifest: %v", err)
	}
	writeTestFile(t, filepath.Join(packageDirectory, "manage.json"), string(contents))
}

func writeTestFile(t *testing.T, path, contents string) {
	t.Helper()

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("create parent directory for %s: %v", path, err)
	}
	if err := os.WriteFile(path, []byte(contents), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func assertSymlink(t *testing.T, destination, wantTarget string) {
	t.Helper()

	info, err := os.Lstat(destination)
	if err != nil {
		t.Fatalf("lstat %s: %v", destination, err)
	}
	if info.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("%s is not a symlink", destination)
	}

	target, err := os.Readlink(destination)
	if err != nil {
		t.Fatalf("readlink %s: %v", destination, err)
	}
	if target != wantTarget {
		t.Fatalf("symlink target = %q, want %q", target, wantTarget)
	}
}
