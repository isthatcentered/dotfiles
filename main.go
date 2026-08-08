package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type Manifest struct {
	Platforms []string `json:"platforms"`
	Targets   []string `json:"targets"`
}

type Link struct {
	Entry                string
	Destination          string
	canonicalEntry       string
	canonicalDestination string
}

func main() {
	if err := Run(".", os.Args[1:], os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

// Run links entries adjacent to active manifests found under repository/home.
func Run(repository string, args []string, stdout, stderr io.Writer) error {
	flags := flag.NewFlagSet("dotfiles", flag.ContinueOnError)
	flags.SetOutput(stderr)
	dryRun := flags.Bool("dry-run", false, "show changes without creating links")
	flags.Usage = func() {
		fmt.Fprintln(stderr, "usage: dotfiles [--dry-run] <macos|linux>")
		flags.PrintDefaults()
	}
	if err := flags.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return nil
		}
		return err
	}
	if flags.NArg() != 1 {
		return fmt.Errorf("usage: dotfiles <macos|linux>")
	}
	platform := flags.Arg(0)
	if platform != "macos" && platform != "linux" {
		return fmt.Errorf("unsupported operating system %q", platform)
	}

	plan, err := buildPlan(repository, platform)
	if err != nil {
		return err
	}
	actions, unchanged, err := validatePlan(plan)
	if err != nil {
		return err
	}

	for _, link := range unchanged {
		fmt.Fprintf(stdout, "exists     %s -> %s\n", link.Destination, link.Entry)
	}
	for _, link := range actions {
		if *dryRun {
			fmt.Fprintf(stdout, "would link %s -> %s\n", link.Destination, link.Entry)
			continue
		}
		if err := os.MkdirAll(filepath.Dir(link.Destination), 0o755); err != nil {
			return err
		}
		if err := os.Symlink(link.Entry, link.Destination); err != nil {
			return err
		}
		fmt.Fprintf(stdout, "linked     %s -> %s\n", link.Destination, link.Entry)
	}

	return nil
}

func buildPlan(repository, platform string) ([]Link, error) {
	repository, err := filepath.Abs(repository)
	if err != nil {
		return nil, err
	}
	homeDirectory := filepath.Join(repository, "home")
	manifestPaths, err := discoverManifestPaths(homeDirectory)
	if err != nil {
		return nil, err
	}
	if len(manifestPaths) == 0 {
		return nil, fmt.Errorf("no manage.json files found under %s", homeDirectory)
	}

	destinations := make(map[string]Link)
	for _, manifestPath := range manifestPaths {
		manifest, err := loadManifest(manifestPath)
		if err != nil {
			return nil, err
		}

		if !supportsPlatform(manifest.Platforms, platform) {
			continue
		}
		type targetDirectory struct {
			path      string
			canonical string
		}
		targetDirectories := make([]targetDirectory, 0, len(manifest.Targets))
		seenTargets := make(map[string]string, len(manifest.Targets))
		for _, targetValue := range manifest.Targets {
			if targetValue == "" {
				return nil, fmt.Errorf("%s: target must not be empty", manifestPath)
			}
			targetPath, err := expandHome(targetValue)
			if err != nil {
				return nil, fmt.Errorf("%s: %w", manifestPath, err)
			}
			if !filepath.IsAbs(targetPath) {
				return nil, fmt.Errorf("%s: target must start with ~ or /", manifestPath)
			}
			canonicalTarget, err := canonicalizeTargetDirectory(targetPath)
			if err != nil {
				return nil, fmt.Errorf("%s: %w", manifestPath, err)
			}
			if previous, exists := seenTargets[canonicalTarget]; exists {
				return nil, fmt.Errorf(
					"%s: targets %s and %s resolve to the same directory",
					manifestPath,
					previous,
					targetPath,
				)
			}
			seenTargets[canonicalTarget] = targetPath
			targetDirectories = append(targetDirectories, targetDirectory{
				path:      targetPath,
				canonical: canonicalTarget,
			})
		}
		containerDirectory := filepath.Dir(manifestPath)
		realContainerDirectory, err := filepath.EvalSymlinks(containerDirectory)
		if err != nil {
			return nil, err
		}
		containerEntries, err := os.ReadDir(containerDirectory)
		if err != nil {
			return nil, fmt.Errorf("read manifest container %s: %w", containerDirectory, err)
		}
		managedEntryCount := 0
		for _, containerEntry := range containerEntries {
			if containerEntry.Name() == "manage.json" {
				continue
			}
			managedEntryCount++
			entry := filepath.Join(containerDirectory, containerEntry.Name())
			realEntry, err := filepath.EvalSymlinks(entry)
			if err != nil {
				return nil, fmt.Errorf("resolve managed entry %s: %w", entry, err)
			}
			relative, err := filepath.Rel(realContainerDirectory, realEntry)
			if err != nil {
				return nil, err
			}
			if relative == ".." || strings.HasPrefix(relative, ".."+string(os.PathSeparator)) {
				return nil, fmt.Errorf("%s: managed entry escapes its container: %s", manifestPath, realEntry)
			}
			for _, target := range targetDirectories {
				destination := filepath.Join(target.path, containerEntry.Name())
				canonicalDestination := filepath.Join(target.canonical, containerEntry.Name())
				if previous, exists := destinations[canonicalDestination]; exists && previous.Entry != entry {
					return nil, fmt.Errorf(
						"%s is claimed by both %s and %s",
						destination,
						previous.Entry,
						entry,
					)
				}
				destinations[canonicalDestination] = Link{
					Entry:                entry,
					Destination:          destination,
					canonicalEntry:       realEntry,
					canonicalDestination: canonicalDestination,
				}
			}
		}
		if managedEntryCount == 0 {
			return nil, fmt.Errorf("%s: active container contains no managed entries", manifestPath)
		}
	}

	plan := make([]Link, 0, len(destinations))
	for _, link := range destinations {
		plan = append(plan, link)
	}
	sort.Slice(plan, func(i, j int) bool {
		return plan[i].Destination < plan[j].Destination
	})
	for _, link := range plan {
		for _, entry := range plan {
			if pathIsInside(entry.canonicalEntry, link.canonicalDestination) {
				return nil, fmt.Errorf(
					"planned destination %s is inside managed entry %s",
					link.Destination,
					entry.Entry,
				)
			}
		}
	}
	for i, parent := range plan {
		for _, child := range plan[i+1:] {
			if pathIsInside(parent.canonicalDestination, child.canonicalDestination) {
				return nil, fmt.Errorf(
					"planned destination %s is nested under planned symlink %s",
					child.Destination,
					parent.Destination,
				)
			}
			if pathIsInside(child.canonicalDestination, parent.canonicalDestination) {
				return nil, fmt.Errorf(
					"planned destination %s is nested under planned symlink %s",
					parent.Destination,
					child.Destination,
				)
			}
		}
	}
	return plan, nil
}

func discoverManifestPaths(homeDirectory string) ([]string, error) {
	var manifestPaths []string
	err := filepath.WalkDir(homeDirectory, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return fmt.Errorf("inspect %s: %w", path, walkErr)
		}
		if !entry.IsDir() {
			return nil
		}

		manifestPath := filepath.Join(path, "manage.json")
		if _, err := os.Lstat(manifestPath); err != nil {
			if os.IsNotExist(err) {
				return nil
			}
			return fmt.Errorf("inspect manifest %s: %w", manifestPath, err)
		}

		manifestPaths = append(manifestPaths, manifestPath)
		return filepath.SkipDir
	})
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	sort.Strings(manifestPaths)
	return manifestPaths, nil
}

func supportsPlatform(platforms []string, selected string) bool {
	for _, platform := range platforms {
		if platform == selected {
			return true
		}
	}
	return false
}

func canonicalizeTargetDirectory(path string) (string, error) {
	path = filepath.Clean(path)
	var missing []string
	for {
		_, err := os.Lstat(path)
		if err == nil {
			resolved, err := filepath.EvalSymlinks(path)
			if err != nil {
				return "", fmt.Errorf("resolve target directory %s: %w", path, err)
			}
			for i := len(missing) - 1; i >= 0; i-- {
				resolved = filepath.Join(resolved, missing[i])
			}
			return resolved, nil
		}
		if !os.IsNotExist(err) {
			return "", fmt.Errorf("inspect target directory %s: %w", path, err)
		}

		parent := filepath.Dir(path)
		if parent == path {
			return "", fmt.Errorf("inspect target directory %s: %w", path, err)
		}
		missing = append(missing, filepath.Base(path))
		path = parent
	}
}

func pathIsInside(parent, child string) bool {
	relative, err := filepath.Rel(parent, child)
	if err != nil || relative == "." {
		return false
	}
	return relative != ".." && !strings.HasPrefix(relative, ".."+string(os.PathSeparator))
}

func loadManifest(path string) (Manifest, error) {
	file, err := os.Open(path)
	if err != nil {
		return Manifest{}, err
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	decoder.DisallowUnknownFields()

	var manifest Manifest
	if err := decoder.Decode(&manifest); err != nil {
		return Manifest{}, fmt.Errorf("%s: invalid JSON: %w", path, err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		if err == nil {
			err = errors.New("multiple JSON values")
		}
		return Manifest{}, fmt.Errorf("%s: invalid JSON: %w", path, err)
	}
	if manifest.Platforms == nil {
		return Manifest{}, fmt.Errorf("%s: platforms must be an array", path)
	}
	if len(manifest.Platforms) == 0 {
		return Manifest{}, fmt.Errorf("%s: platforms must not be empty", path)
	}
	seenPlatforms := make(map[string]struct{}, len(manifest.Platforms))
	for _, platform := range manifest.Platforms {
		if platform != "macos" && platform != "linux" {
			return Manifest{}, fmt.Errorf("%s: unsupported operating system %q", path, platform)
		}
		if _, exists := seenPlatforms[platform]; exists {
			return Manifest{}, fmt.Errorf("%s: duplicate operating system %q", path, platform)
		}
		seenPlatforms[platform] = struct{}{}
	}
	if manifest.Targets == nil {
		return Manifest{}, fmt.Errorf("%s: targets must be an array", path)
	}
	if len(manifest.Targets) == 0 {
		return Manifest{}, fmt.Errorf("%s: targets must not be empty", path)
	}
	return manifest, nil
}

func expandHome(path string) (string, error) {
	prefix := "~" + string(os.PathSeparator)
	if path == "~" || strings.HasPrefix(path, prefix) {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		if path == "~" {
			return home, nil
		}
		return filepath.Join(home, strings.TrimPrefix(path, prefix)), nil
	}
	if strings.HasPrefix(path, "~") {
		return "", fmt.Errorf("~user paths are not supported: %s", path)
	}
	return path, nil
}

func validatePlan(plan []Link) (actions []Link, unchanged []Link, err error) {
	for _, link := range plan {
		info, statErr := os.Lstat(link.Destination)
		if os.IsNotExist(statErr) {
			actions = append(actions, link)
			continue
		}
		if statErr != nil {
			return nil, nil, statErr
		}
		if info.Mode()&os.ModeSymlink == 0 {
			return nil, nil, fmt.Errorf("%s already exists and is not a symlink", link.Destination)
		}

		currentTarget, resolveErr := filepath.EvalSymlinks(link.Destination)
		if resolveErr != nil {
			return nil, nil, fmt.Errorf("%s is a broken symlink", link.Destination)
		}
		sourceTarget, resolveErr := filepath.EvalSymlinks(link.Entry)
		if resolveErr != nil {
			return nil, nil, resolveErr
		}
		if currentTarget != sourceTarget {
			return nil, nil, fmt.Errorf("%s points to %s instead of %s", link.Destination, currentTarget, link.Entry)
		}
		unchanged = append(unchanged, link)
	}
	return actions, unchanged, nil
}
