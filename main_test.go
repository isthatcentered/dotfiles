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

func TestRunLinksEveryManagedEntryExceptManifest(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := filepath.Join(t.TempDir(), "target with spaces")

	writeTestFile(t, filepath.Join(containerDirectory, "dummy.config"), "dummy config\n")
	writeTestFile(t, filepath.Join(containerDirectory, ".hidden"), "hidden config\n")
	writeTestFile(t, filepath.Join(containerDirectory, "folder", "nested.txt"), "nested content\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos", "linux"},
		Targets:   []string{targetDirectory},
	})

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	if err := Run(repository, []string{"macos"}, &stdout, &stderr); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	assertSymlink(t,
		filepath.Join(targetDirectory, ".hidden"),
		filepath.Join(containerDirectory, ".hidden"),
	)
	assertSymlink(t,
		filepath.Join(targetDirectory, "dummy.config"),
		filepath.Join(containerDirectory, "dummy.config"),
	)
	assertSymlink(t,
		filepath.Join(targetDirectory, "folder"),
		filepath.Join(containerDirectory, "folder"),
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
		filepath.Join(targetDirectory, ".hidden"),
		filepath.Join(targetDirectory, "dummy.config"),
		filepath.Join(targetDirectory, "folder"),
	} {
		if !strings.Contains(stdout.String(), "linked     "+destination) {
			t.Errorf("stdout = %q, want linked line for %s", stdout.String(), destination)
		}
	}
	if _, err := os.Lstat(filepath.Join(targetDirectory, "manage.json")); !os.IsNotExist(err) {
		t.Fatalf("manifest destination stat error = %v, want not-exist", err)
	}
}

func TestRunFansOutEveryManagedEntryToEveryTarget(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	targetRoot := t.TempDir()
	firstTarget := filepath.Join(targetRoot, "a-target")
	secondTarget := filepath.Join(targetRoot, "z-target")
	firstSource := filepath.Join(containerDirectory, "a.config")
	secondSource := filepath.Join(containerDirectory, "z.config")

	writeTestFile(t, firstSource, "first\n")
	writeTestFile(t, secondSource, "second\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{secondTarget, firstTarget},
	})

	var stdout bytes.Buffer
	if err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	for _, target := range []string{firstTarget, secondTarget} {
		assertSymlink(t, filepath.Join(target, "a.config"), firstSource)
		assertSymlink(t, filepath.Join(target, "z.config"), secondSource)
	}
	want := "linked     " + filepath.Join(firstTarget, "a.config") + " -> " + firstSource + "\n" +
		"linked     " + filepath.Join(firstTarget, "z.config") + " -> " + secondSource + "\n" +
		"linked     " + filepath.Join(secondTarget, "a.config") + " -> " + firstSource + "\n" +
		"linked     " + filepath.Join(secondTarget, "z.config") + " -> " + secondSource + "\n"
	if got := stdout.String(); got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunDryRunReportsLinksWithoutChangingFilesystem(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := filepath.Join(t.TempDir(), "missing", "target")
	source := filepath.Join(containerDirectory, "dummy.config")
	destination := filepath.Join(targetDirectory, "dummy.config")

	writeTestFile(t, source, "dummy\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
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
	containerDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := t.TempDir()
	source := filepath.Join(containerDirectory, "dummy.config")
	destination := filepath.Join(targetDirectory, "dummy.config")

	writeTestFile(t, source, "dummy\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
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

func TestRunRelinksExistingSymlinkToExactPlannedEntry(t *testing.T) {
	tests := []struct {
		name           string
		existingTarget func(t *testing.T, source, destination string) string
	}{
		{
			name: "wrong symlink",
			existingTarget: func(t *testing.T, _, _ string) string {
				t.Helper()
				wrong := filepath.Join(t.TempDir(), "wrong.config")
				writeTestFile(t, wrong, "wrong\n")
				return wrong
			},
		},
		{
			name: "broken symlink",
			existingTarget: func(t *testing.T, _, _ string) string {
				t.Helper()
				return filepath.Join(t.TempDir(), "missing.config")
			},
		},
		{
			name: "equivalent relative symlink",
			existingTarget: func(t *testing.T, source, destination string) string {
				t.Helper()
				relative, err := filepath.Rel(filepath.Dir(destination), source)
				if err != nil {
					t.Fatalf("make relative symlink target: %v", err)
				}
				return relative
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			containerDirectory := filepath.Join(repository, "home", "dummy")
			targetDirectory := t.TempDir()
			source := filepath.Join(containerDirectory, "dummy.config")
			destination := filepath.Join(targetDirectory, "dummy.config")

			writeTestFile(t, source, "dummy\n")
			writeTestManifest(t, containerDirectory, testManifest{
				Platforms: []string{"macos"},
				Targets:   []string{targetDirectory},
			})
			if err := os.Symlink(test.existingTarget(t, source, destination), destination); err != nil {
				t.Fatalf("create existing symlink: %v", err)
			}

			var stdout bytes.Buffer
			if err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{}); err != nil {
				t.Fatalf("Run() error = %v", err)
			}
			assertSymlink(t, destination, source)
			if got, want := stdout.String(), "relinked   "+destination+" -> "+source+"\n"; got != want {
				t.Fatalf("stdout = %q, want %q", got, want)
			}
		})
	}
}

func TestRunDryRunReportsRelinkWithoutChangingSymlink(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := t.TempDir()
	source := filepath.Join(containerDirectory, "dummy.config")
	destination := filepath.Join(targetDirectory, "dummy.config")
	oldTarget := filepath.Join(t.TempDir(), "old.config")

	writeTestFile(t, source, "dummy\n")
	writeTestFile(t, oldTarget, "old\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
	})
	if err := os.Symlink(oldTarget, destination); err != nil {
		t.Fatalf("create existing symlink: %v", err)
	}

	var stdout bytes.Buffer
	if err := Run(repository, []string{"--dry-run", "macos"}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	assertSymlink(t, destination, oldTarget)
	if got, want := stdout.String(), "would relink "+destination+" -> "+source+"\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunRepairsSymlinkAfterRepositoryMoves(t *testing.T) {
	workspace := t.TempDir()
	repository := filepath.Join(workspace, "original")
	containerDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := t.TempDir()
	oldSource := filepath.Join(containerDirectory, "dummy.config")
	destination := filepath.Join(targetDirectory, "dummy.config")

	writeTestFile(t, oldSource, "dummy\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
	})
	if err := Run(repository, []string{"macos"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("initial Run() error = %v", err)
	}
	assertSymlink(t, destination, oldSource)

	movedRepository := filepath.Join(workspace, "moved")
	if err := os.Rename(repository, movedRepository); err != nil {
		t.Fatalf("move repository: %v", err)
	}
	newSource := filepath.Join(movedRepository, "home", "dummy", "dummy.config")

	var stdout bytes.Buffer
	if err := Run(movedRepository, []string{"macos"}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() after move error = %v", err)
	}
	assertSymlink(t, destination, newSource)
	if got, want := stdout.String(), "relinked   "+destination+" -> "+newSource+"\n"; got != want {
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
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			containerDirectory := filepath.Join(repository, "home", "dummy")
			targetDirectory := t.TempDir()
			firstSource := filepath.Join(containerDirectory, "a.config")
			conflictingSource := filepath.Join(containerDirectory, "z.config")
			firstDestination := filepath.Join(targetDirectory, "a.config")
			conflictingDestination := filepath.Join(targetDirectory, "z.config")
			oldTarget := filepath.Join(t.TempDir(), "old.config")

			writeTestFile(t, firstSource, "first\n")
			writeTestFile(t, conflictingSource, "conflict\n")
			writeTestFile(t, oldTarget, "old\n")
			writeTestManifest(t, containerDirectory, testManifest{
				Platforms: []string{"macos"},
				Targets:   []string{targetDirectory},
			})
			if err := os.Symlink(oldTarget, firstDestination); err != nil {
				t.Fatalf("create relinkable destination: %v", err)
			}
			test.makeTarget(t, conflictingDestination)

			var stdout bytes.Buffer
			err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
			if err == nil {
				t.Fatal("Run() error = nil, want destination collision")
			}
			if !strings.Contains(err.Error(), conflictingDestination) {
				t.Fatalf("Run() error = %q, want destination path", err)
			}
			assertSymlink(t, firstDestination, oldTarget)
			if got := stdout.String(); got != "" {
				t.Fatalf("stdout = %q, want empty", got)
			}
		})
	}
}

func TestRunSelectsOnlyContainersForRequestedOperatingSystem(t *testing.T) {
	repository := t.TempDir()
	macOSTarget := filepath.Join(t.TempDir(), "macos")
	linuxTarget := filepath.Join(t.TempDir(), "linux")
	macOSContainer := filepath.Join(repository, "home", "dummy", "macos")
	linuxContainer := filepath.Join(repository, "home", "dummy", "linux")
	macOSSource := filepath.Join(macOSContainer, "dummy.config")
	linuxSource := filepath.Join(linuxContainer, "dummy.config")

	writeTestFile(t, macOSSource, "macos\n")
	writeTestManifest(t, macOSContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{macOSTarget},
	})
	writeTestFile(t, linuxSource, "linux\n")
	writeTestManifest(t, linuxContainer, testManifest{
		Platforms: []string{"linux"},
		Targets:   []string{linuxTarget},
	})

	if err := Run(repository, []string{"linux"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	assertSymlink(t, filepath.Join(linuxTarget, "dummy.config"), linuxSource)
	if _, err := os.Lstat(filepath.Join(macOSTarget, "dummy.config")); !os.IsNotExist(err) {
		t.Fatalf("macOS destination stat error = %v, want not-exist", err)
	}
}

func TestRunRelinksDestinationWhenSelectedPlatformChanges(t *testing.T) {
	repository := t.TempDir()
	targetDirectory := t.TempDir()
	macOSContainer := filepath.Join(repository, "home", "dummy", "macos")
	linuxContainer := filepath.Join(repository, "home", "dummy", "linux")
	macOSSource := filepath.Join(macOSContainer, "dummy.config")
	linuxSource := filepath.Join(linuxContainer, "dummy.config")
	destination := filepath.Join(targetDirectory, "dummy.config")

	writeTestFile(t, macOSSource, "macos\n")
	writeTestManifest(t, macOSContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
	})
	writeTestFile(t, linuxSource, "linux\n")
	writeTestManifest(t, linuxContainer, testManifest{
		Platforms: []string{"linux"},
		Targets:   []string{targetDirectory},
	})

	if err := Run(repository, []string{"linux"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("Linux Run() error = %v", err)
	}
	assertSymlink(t, destination, linuxSource)

	var stdout bytes.Buffer
	if err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatalf("macOS Run() error = %v", err)
	}
	assertSymlink(t, destination, macOSSource)
	if got, want := stdout.String(), "relinked   "+destination+" -> "+macOSSource+"\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunDoesNotInspectInactiveContainerEntriesOrTargetPaths(t *testing.T) {
	repository := t.TempDir()
	macOSContainer := filepath.Join(repository, "home", "dummy", "macos")
	linuxContainer := filepath.Join(repository, "home", "dummy", "linux")
	macOSTarget := t.TempDir()
	source := filepath.Join(macOSContainer, "dummy.config")

	writeTestFile(t, source, "dummy\n")
	writeTestManifest(t, macOSContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{macOSTarget},
	})
	if err := os.MkdirAll(linuxContainer, 0o755); err != nil {
		t.Fatalf("create inactive container: %v", err)
	}
	writeTestManifest(t, linuxContainer, testManifest{
		Platforms: []string{"linux"},
		Targets:   []string{"relative/path", ""},
	})

	if err := Run(repository, []string{"macos"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	assertSymlink(t, filepath.Join(macOSTarget, "dummy.config"), source)
}

func TestRunValidatesInactiveManifestSchema(t *testing.T) {
	repository := t.TempDir()
	activeContainer := filepath.Join(repository, "home", "dummy", "macos")
	inactiveContainer := filepath.Join(repository, "home", "dummy", "linux")
	targetDirectory := t.TempDir()

	writeTestFile(t, filepath.Join(activeContainer, "config"), "config\n")
	writeTestManifest(t, activeContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
	})
	writeTestFile(t, filepath.Join(inactiveContainer, "config"), "config\n")
	writeTestFile(t, filepath.Join(inactiveContainer, "manage.json"), `{"platforms":["linux"],"targets":null}`)

	err := Run(repository, []string{"macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "targets must be an array") {
		t.Fatalf("Run() error = %v, want inactive-manifest schema error", err)
	}
	if _, err := os.Lstat(filepath.Join(targetDirectory, "config")); !os.IsNotExist(err) {
		t.Fatalf("active destination changed before validation completed: %v", err)
	}
}

func TestRunSucceedsWhenNoManifestSupportsSelectedPlatform(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "linux-only")

	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"linux"},
		Targets:   []string{"relative/path"},
	})

	var stdout bytes.Buffer
	if err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
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
			containerDirectory := filepath.Join(repository, "home", "dummy")
			fakeHome := t.TempDir()
			t.Setenv("HOME", fakeHome)

			writeTestFile(t, filepath.Join(containerDirectory, "dummy.config"), "dummy\n")
			writeTestManifest(t, containerDirectory, testManifest{
				Platforms: []string{"macos"},
				Targets:   []string{test.target},
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
	containerDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := t.TempDir()
	t.Setenv("HOME", "")

	writeTestFile(t, filepath.Join(containerDirectory, "dummy.config"), "dummy\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
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

func TestRunDoesNotFollowDirectorySymlinksDuringDiscovery(t *testing.T) {
	repository := t.TempDir()
	homeDirectory := filepath.Join(repository, "home")
	targetDirectory := t.TempDir()

	validContainer := filepath.Join(homeDirectory, "valid")
	validEntry := filepath.Join(validContainer, "config")
	writeTestFile(t, validEntry, "valid\n")
	writeTestManifest(t, validContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
	})

	externalContainer := t.TempDir()
	writeTestFile(t, filepath.Join(externalContainer, "external"), "external\n")
	writeTestManifest(t, externalContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
	})
	if err := os.Symlink(externalContainer, filepath.Join(homeDirectory, "external-link")); err != nil {
		t.Fatalf("create directory symlink: %v", err)
	}

	if err := Run(repository, []string{"macos"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	assertSymlink(t, filepath.Join(targetDirectory, "config"), validEntry)
	if _, err := os.Lstat(filepath.Join(targetDirectory, "external")); !os.IsNotExist(err) {
		t.Fatalf("external destination stat error = %v, want not-exist", err)
	}
}

func TestRunTreatsManifestContainerAsDiscoveryBoundary(t *testing.T) {
	repository := t.TempDir()
	container := filepath.Join(repository, "home", "parent")
	targetDirectory := t.TempDir()
	nestedDirectory := filepath.Join(container, "nested")

	writeTestFile(t, filepath.Join(nestedDirectory, "manage.json"), "not valid JSON")
	writeTestManifest(t, container, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
	})

	if err := Run(repository, []string{"macos"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	assertSymlink(t, filepath.Join(targetDirectory, "nested"), nestedDirectory)
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
				return fmt.Sprintf(`{"platforms":["macos"],"targets":[%q],"typo":true}`, target)
			},
			wantErr: "invalid JSON",
		},
		{
			name: "legacy targets object",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"targets":{"macos":[%q]}}`, target)
			},
			wantErr: "invalid JSON",
		},
		{
			name: "trailing JSON value",
			manifest: func(target string) string {
				return fmt.Sprintf(`{"platforms":["macos"],"targets":[%q]} {}`, target)
			},
			wantErr: "invalid JSON",
		},
		{
			name:     "missing platforms",
			manifest: func(string) string { return `{"targets":["/tmp"]}` },
			wantErr:  "platforms must be an array",
		},
		{
			name:     "null platforms",
			manifest: func(string) string { return `{"platforms":null,"targets":["/tmp"]}` },
			wantErr:  "platforms must be an array",
		},
		{
			name:     "platforms is not an array",
			manifest: func(string) string { return `{"platforms":"macos","targets":["/tmp"]}` },
			wantErr:  "invalid JSON",
		},
		{
			name:     "empty platforms",
			manifest: func(string) string { return `{"platforms":[],"targets":["/tmp"]}` },
			wantErr:  "platforms must not be empty",
		},
		{
			name:     "platforms contains non-string",
			manifest: func(string) string { return `{"platforms":[42],"targets":["/tmp"]}` },
			wantErr:  "invalid JSON",
		},
		{
			name:     "unknown platform",
			manifest: func(string) string { return `{"platforms":["windows"],"targets":["/tmp"]}` },
			wantErr:  "unsupported operating system",
		},
		{
			name:     "duplicate platform",
			manifest: func(string) string { return `{"platforms":["macos","macos"],"targets":["/tmp"]}` },
			wantErr:  "duplicate operating system",
		},
		{
			name:     "missing targets",
			manifest: func(string) string { return `{"platforms":["macos"]}` },
			wantErr:  "targets must be an array",
		},
		{
			name:     "null targets",
			manifest: func(string) string { return `{"platforms":["macos"],"targets":null}` },
			wantErr:  "targets must be an array",
		},
		{
			name:     "targets is not an array",
			manifest: func(string) string { return `{"platforms":["macos"],"targets":"/tmp"}` },
			wantErr:  "invalid JSON",
		},
		{
			name:     "empty targets",
			manifest: func(string) string { return `{"platforms":["macos"],"targets":[]}` },
			wantErr:  "targets must not be empty",
		},
		{
			name:     "targets contains non-string",
			manifest: func(string) string { return `{"platforms":["macos"],"targets":[42]}` },
			wantErr:  "invalid JSON",
		},
		{
			name:     "empty target path",
			manifest: func(string) string { return `{"platforms":["macos"],"targets":[""]}` },
			wantErr:  "must not be empty",
		},
		{
			name:     "relative target",
			manifest: func(string) string { return `{"platforms":["macos"],"targets":["relative/path"]}` },
			wantErr:  "target must start with ~ or /",
		},
		{
			name:     "named user home target",
			manifest: func(string) string { return `{"platforms":["macos"],"targets":["~someone/config"]}` },
			wantErr:  "~user paths are not supported",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			containerDirectory := filepath.Join(repository, "home", "dummy")
			writeTestFile(t, filepath.Join(containerDirectory, "dummy.config"), "dummy\n")
			writeTestFile(t, filepath.Join(containerDirectory, "manage.json"), test.manifest(t.TempDir()))

			err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
			if err == nil || !strings.Contains(err.Error(), test.wantErr) {
				t.Fatalf("Run() error = %v, want containing %q", err, test.wantErr)
			}
		})
	}
}

func TestRunRejectsActiveContainerWithoutManagedEntries(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{t.TempDir()},
	})

	err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "active container contains no managed entries") {
		t.Fatalf("Run() error = %v, want empty-container error", err)
	}
}

func TestRunRejectsManagedEntrySymlinkThatEscapesContainer(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	externalEntry := filepath.Join(t.TempDir(), "external.config")
	linkedEntry := filepath.Join(containerDirectory, "external.config")

	writeTestFile(t, externalEntry, "external\n")
	if err := os.MkdirAll(containerDirectory, 0o755); err != nil {
		t.Fatalf("create container directory: %v", err)
	}
	if err := os.Symlink(externalEntry, linkedEntry); err != nil {
		t.Fatalf("create escaping managed-entry symlink: %v", err)
	}
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{t.TempDir()},
	})

	err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "managed entry escapes its container") {
		t.Fatalf("Run() error = %v, want container-escape error", err)
	}
}

func TestRunRejectsBrokenManagedEntrySymlink(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	brokenEntry := filepath.Join(containerDirectory, "broken.config")

	if err := os.MkdirAll(containerDirectory, 0o755); err != nil {
		t.Fatalf("create container directory: %v", err)
	}
	if err := os.Symlink(filepath.Join(t.TempDir(), "missing"), brokenEntry); err != nil {
		t.Fatalf("create broken managed-entry symlink: %v", err)
	}
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{t.TempDir()},
	})

	err := Run(repository, []string{"--dry-run", "macos"}, &bytes.Buffer{}, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "resolve managed entry") {
		t.Fatalf("Run() error = %v, want broken-managed-entry error", err)
	}
}

func TestRunAcceptsManagedEntrySymlinkWithinContainer(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	targetDirectory := t.TempDir()
	entry := filepath.Join(containerDirectory, "config")
	alias := filepath.Join(containerDirectory, "config-alias")

	writeTestFile(t, entry, "config\n")
	if err := os.Symlink(entry, alias); err != nil {
		t.Fatalf("create internal managed-entry symlink: %v", err)
	}
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetDirectory},
	})

	if err := Run(repository, []string{"macos"}, &bytes.Buffer{}, &bytes.Buffer{}); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	assertSymlink(t, filepath.Join(targetDirectory, "config"), entry)
	assertSymlink(t, filepath.Join(targetDirectory, "config-alias"), alias)
}

func TestRunRejectsHomeTargetWhenHomeIsUnavailable(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	t.Setenv("HOME", "")

	writeTestFile(t, filepath.Join(containerDirectory, "dummy.config"), "dummy\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{"~"},
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

	firstContainer := filepath.Join(repository, "home", "first")
	writeTestFile(t, filepath.Join(firstContainer, "first.config"), "first\n")
	writeTestManifest(t, firstContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{goodTarget},
	})

	secondContainer := filepath.Join(repository, "home", "second")
	writeTestFile(t, filepath.Join(secondContainer, "second.config"), "second\n")
	writeTestManifest(t, secondContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{blockedTarget},
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

func TestRunRejectsDuplicateEffectiveTargetsBeforeMakingChanges(t *testing.T) {
	tests := []struct {
		name          string
		duplicatePath func(t *testing.T, target string) string
	}{
		{
			name: "same path",
			duplicatePath: func(t *testing.T, target string) string {
				t.Helper()
				return target
			},
		},
		{
			name: "symlink alias",
			duplicatePath: func(t *testing.T, target string) string {
				t.Helper()
				alias := filepath.Join(filepath.Dir(target), "alias")
				if err := os.Symlink(target, alias); err != nil {
					t.Fatalf("create target alias: %v", err)
				}
				return alias
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			repository := t.TempDir()
			containerDirectory := filepath.Join(repository, "home", "dummy")
			targetRoot := t.TempDir()
			goodTarget := filepath.Join(targetRoot, "a-good")
			duplicateTarget := filepath.Join(targetRoot, "duplicate")
			if err := os.Mkdir(duplicateTarget, 0o755); err != nil {
				t.Fatalf("create duplicate target: %v", err)
			}

			writeTestFile(t, filepath.Join(containerDirectory, "dummy.config"), "dummy\n")
			writeTestManifest(t, containerDirectory, testManifest{
				Platforms: []string{"macos"},
				Targets:   []string{goodTarget, duplicateTarget, test.duplicatePath(t, duplicateTarget)},
			})

			var stdout bytes.Buffer
			err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
			if err == nil || !strings.Contains(err.Error(), "resolve to the same directory") {
				t.Fatalf("Run() error = %v, want duplicate-target error", err)
			}
			if _, err := os.Lstat(filepath.Join(goodTarget, "dummy.config")); !os.IsNotExist(err) {
				t.Fatalf("good target changed before validation completed: %v", err)
			}
			if got := stdout.String(); got != "" {
				t.Fatalf("stdout = %q, want empty", got)
			}
		})
	}
}

func TestRunRejectsDifferentManagedEntriesClaimingSameDestination(t *testing.T) {
	repository := t.TempDir()
	targetDirectory := t.TempDir()
	for _, containerName := range []string{"first", "second"} {
		containerDirectory := filepath.Join(repository, "home", containerName)
		writeTestFile(t, filepath.Join(containerDirectory, "config"), containerName+"\n")
		writeTestManifest(t, containerDirectory, testManifest{
			Platforms: []string{"macos"},
			Targets:   []string{targetDirectory},
		})
	}

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
}

func TestRunRejectsDestinationNestedUnderAnotherPlannedLink(t *testing.T) {
	repository := t.TempDir()
	targetRoot := t.TempDir()

	nvimContainer := filepath.Join(repository, "home", "neovim")
	nvimSource := filepath.Join(nvimContainer, "nvim")
	writeTestFile(t, filepath.Join(nvimSource, "init.lua"), "-- init\n")
	writeTestManifest(t, nvimContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetRoot},
	})

	pluginContainer := filepath.Join(repository, "home", "plugin")
	writeTestFile(t, filepath.Join(pluginContainer, "plugin"), "plugin\n")
	writeTestManifest(t, pluginContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{filepath.Join(targetRoot, "nvim")},
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
		t.Fatalf("nested link was created inside managed entry: %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
}

func TestRunRejectsNestedDestinationsCreatedByFanOut(t *testing.T) {
	repository := t.TempDir()
	targetRoot := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "neovim")
	source := filepath.Join(containerDirectory, "nvim")
	writeTestFile(t, filepath.Join(source, "init.lua"), "-- init\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{targetRoot, filepath.Join(targetRoot, "nvim", "plugins")},
	})

	var stdout bytes.Buffer
	err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "nested") {
		t.Fatalf("Run() error = %v, want nested-destination error", err)
	}
	if _, err := os.Lstat(filepath.Join(targetRoot, "nvim")); !os.IsNotExist(err) {
		t.Fatalf("target changed before validation completed: %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
}

func TestRunRejectsDestinationInsideManagedEntry(t *testing.T) {
	repository := t.TempDir()
	containerDirectory := filepath.Join(repository, "home", "dummy")
	source := filepath.Join(containerDirectory, "config")
	target := filepath.Join(source, "generated")
	writeTestFile(t, filepath.Join(source, "settings.conf"), "settings\n")
	writeTestManifest(t, containerDirectory, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{target},
	})

	var stdout bytes.Buffer
	err := Run(repository, []string{"macos"}, &stdout, &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "inside managed entry") {
		t.Fatalf("Run() error = %v, want managed-entry error", err)
	}
	if _, err := os.Lstat(target); !os.IsNotExist(err) {
		t.Fatalf("managed entry changed before validation completed: %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
}

func TestRunRejectsDifferentManagedEntriesClaimingTargetDirectoryAliases(t *testing.T) {
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

	firstContainer := filepath.Join(repository, "home", "first")
	writeTestFile(t, filepath.Join(firstContainer, "config"), "first\n")
	writeTestManifest(t, firstContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{realTarget},
	})

	secondContainer := filepath.Join(repository, "home", "second")
	writeTestFile(t, filepath.Join(secondContainer, "config"), "second\n")
	writeTestManifest(t, secondContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{aliasTarget},
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

	firstContainer := filepath.Join(repository, "home", "first")
	writeTestFile(t, filepath.Join(firstContainer, "first.config"), "first\n")
	writeTestManifest(t, firstContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{goodTarget},
	})

	secondContainer := filepath.Join(repository, "home", "second")
	writeTestFile(t, filepath.Join(secondContainer, "second.config"), "second\n")
	writeTestManifest(t, secondContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{filepath.Join(danglingAncestor, "nested")},
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

	nvimContainer := filepath.Join(repository, "home", "neovim")
	writeTestFile(t, filepath.Join(nvimContainer, "nvim", "init.lua"), "-- init\n")
	writeTestManifest(t, nvimContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{aliasTarget},
	})

	pluginContainer := filepath.Join(repository, "home", "plugin")
	writeTestFile(t, filepath.Join(pluginContainer, "plugin"), "plugin\n")
	writeTestManifest(t, pluginContainer, testManifest{
		Platforms: []string{"macos"},
		Targets:   []string{filepath.Join(realTarget, "nvim")},
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
	Platforms []string `json:"platforms"`
	Targets   []string `json:"targets"`
}

func writeTestManifest(t *testing.T, containerDirectory string, manifest testManifest) {
	t.Helper()

	contents, err := json.Marshal(manifest)
	if err != nil {
		t.Fatalf("marshal manifest: %v", err)
	}
	writeTestFile(t, filepath.Join(containerDirectory, "manage.json"), string(contents))
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
