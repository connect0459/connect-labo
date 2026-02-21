package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"connect-labo/dev-settings/coding-agents/sync-cmd/internal/checksum"
	"connect-labo/dev-settings/coding-agents/sync-cmd/internal/dirsync"
	"connect-labo/dev-settings/coding-agents/sync-cmd/internal/permissions"
	"connect-labo/dev-settings/coding-agents/sync-cmd/internal/symlink"
)

func main() {
	os.Exit(run())
}

func run() int {
	exe, err := os.Executable()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to get executable path: %v\n", err)
		return 1
	}
	sourceDir := filepath.Dir(filepath.Dir(filepath.Clean(exe)))

	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to get home directory: %v\n", err)
		return 1
	}

	centralDir := filepath.Join(home, ".connect0459", "coding-agents")
	claudeDir := filepath.Join(home, ".claude")
	githubDir := filepath.Join(home, ".github")

	sourceAgentsMD := filepath.Join(sourceDir, "AGENTS.md")
	sourceAgentDocs := filepath.Join(sourceDir, "agent-docs")
	sourceSettings := filepath.Join(sourceDir, "claude", "settings.json")

	centralAgentsMD := filepath.Join(centralDir, "AGENTS.md")
	centralAgentDocs := filepath.Join(centralDir, "agent-docs")

	claudeMD := filepath.Join(claudeDir, "CLAUDE.md")
	claudeSettings := filepath.Join(claudeDir, "settings.json")
	copilotInstructions := filepath.Join(githubDir, "copilot-instructions.md")

	fmt.Println("Coding agents configuration sync tool")
	fmt.Printf("Source:  %s\n", sourceDir)
	fmt.Printf("Central: %s\n", centralDir)
	fmt.Printf("Claude:  %s\n", claudeDir)
	fmt.Println()

	before := map[string]string{
		"agents_md":  checksum.Of(centralAgentsMD),
		"agent_docs": checksum.Of(centralAgentDocs),
		"settings":   checksum.Of(claudeSettings),
	}

	os.MkdirAll(centralAgentDocs, 0755)
	os.MkdirAll(claudeDir, 0755)
	os.MkdirAll(githubDir, 0755)

	fmt.Println("Syncing AGENTS.md to central location")
	if err := dirsync.CopyFile(sourceAgentsMD, centralAgentsMD); err != nil {
		fmt.Fprintf(os.Stderr, "failed to copy AGENTS.md: %v\n", err)
		return 1
	}

	fmt.Println("Syncing agent-docs directory to central location")
	if err := dirsync.Sync(sourceAgentDocs, centralAgentDocs); err != nil {
		fmt.Fprintf(os.Stderr, "failed to sync agent-docs: %v\n", err)
		return 1
	}

	settingsExists := false
	if _, err := os.Stat(sourceSettings); err == nil {
		settingsExists = true
		fmt.Println("Syncing permissions from settings.json")
		if err := permissions.Merge(sourceSettings, claudeSettings); err != nil {
			fmt.Fprintf(os.Stderr, "failed to merge permissions: %v\n", err)
			return 1
		}
	}

	fmt.Println()
	fmt.Println("Setting up symlinks...")
	if err := symlink.Setup(centralAgentsMD, claudeMD); err != nil {
		fmt.Fprintf(os.Stderr, "failed to setup symlink for CLAUDE.md: %v\n", err)
		return 1
	}
	fmt.Printf("  %s -> %s\n", claudeMD, centralAgentsMD)

	if err := symlink.Setup(centralAgentsMD, copilotInstructions); err != nil {
		fmt.Fprintf(os.Stderr, "failed to setup symlink for copilot-instructions.md: %v\n", err)
		return 1
	}
	fmt.Printf("  %s -> %s\n", copilotInstructions, centralAgentsMD)
	fmt.Println()

	after := map[string]string{
		"agents_md":  checksum.Of(centralAgentsMD),
		"agent_docs": checksum.Of(centralAgentDocs),
		"settings":   checksum.Of(claudeSettings),
	}

	line := strings.Repeat("━", 38)
	fmt.Println(line)
	fmt.Println("Change Detection Report")
	fmt.Println(line)

	hasChanges := false

	type item struct {
		label string
		key   string
	}
	items := []item{
		{"AGENTS.md", "agents_md"},
		{"agent-docs/", "agent_docs"},
	}
	if settingsExists {
		items = append(items, item{"settings.json", "settings"})
	}

	for _, it := range items {
		if before[it.key] != after[it.key] {
			fmt.Printf("  ✓ %s (updated)\n", it.label)
			hasChanges = true
		} else {
			fmt.Printf("  - %s (no changes)\n", it.label)
		}
	}

	if isSymlink(claudeMD) {
		fmt.Println("  ✓ Claude symlink (active)")
		hasChanges = true
	}

	if isSymlink(copilotInstructions) {
		fmt.Println("  ✓ GitHub Copilot symlink (active)")
		hasChanges = true
	}

	fmt.Println(line)

	if hasChanges {
		fmt.Println("✓ Changes were applied successfully")
	} else {
		fmt.Println("✓ All files were already up to date")
	}

	return 0
}

func isSymlink(path string) bool {
	info, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeSymlink != 0
}
