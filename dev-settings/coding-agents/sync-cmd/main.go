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
	"connect-labo/dev-settings/coding-agents/sync-cmd/internal/term"
)

func main() {
	os.Exit(run())
}

func run() int {
	exe, err := os.Executable()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", term.Red(fmt.Sprintf("failed to get executable path: %v", err)))
		return 1
	}
	sourceDir := filepath.Dir(filepath.Dir(filepath.Clean(exe)))

	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", term.Red(fmt.Sprintf("failed to get home directory: %v", err)))
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

	fmt.Println(term.Bold("Coding agents configuration sync tool"))
	fmt.Printf("%s  %s\n", term.Dim("Source:"), sourceDir)
	fmt.Printf("%s %s\n", term.Dim("Central:"), centralDir)
	fmt.Printf("%s  %s\n", term.Dim("Claude:"), claudeDir)
	fmt.Println()

	before := map[string]string{
		"agents_md":  checksum.Of(centralAgentsMD),
		"agent_docs": checksum.Of(centralAgentDocs),
		"settings":   checksum.Of(claudeSettings),
	}

	os.MkdirAll(centralAgentDocs, 0755)
	os.MkdirAll(claudeDir, 0755)
	os.MkdirAll(githubDir, 0755)

	fmt.Println(term.Cyan("Syncing AGENTS.md to central location"))
	if err := dirsync.CopyFile(sourceAgentsMD, centralAgentsMD); err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", term.Red(fmt.Sprintf("failed to copy AGENTS.md: %v", err)))
		return 1
	}

	fmt.Println(term.Cyan("Syncing agent-docs directory to central location"))
	if err := dirsync.Sync(sourceAgentDocs, centralAgentDocs); err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", term.Red(fmt.Sprintf("failed to sync agent-docs: %v", err)))
		return 1
	}

	settingsExists := false
	if _, err := os.Stat(sourceSettings); err == nil {
		settingsExists = true
		fmt.Println(term.Cyan("Syncing permissions from settings.json"))
		if err := permissions.Merge(sourceSettings, claudeSettings); err != nil {
			fmt.Fprintf(os.Stderr, "%s\n", term.Red(fmt.Sprintf("failed to merge permissions: %v", err)))
			return 1
		}
	}

	fmt.Println()
	fmt.Println(term.Cyan("Setting up symlinks..."))
	if err := symlink.Setup(centralAgentsMD, claudeMD); err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", term.Red(fmt.Sprintf("failed to setup symlink for CLAUDE.md: %v", err)))
		return 1
	}
	fmt.Printf("  %s -> %s\n", claudeMD, centralAgentsMD)

	if err := symlink.Setup(centralAgentsMD, copilotInstructions); err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", term.Red(fmt.Sprintf("failed to setup symlink for copilot-instructions.md: %v", err)))
		return 1
	}
	fmt.Printf("  %s -> %s\n", copilotInstructions, centralAgentsMD)
	fmt.Println()

	after := map[string]string{
		"agents_md":  checksum.Of(centralAgentsMD),
		"agent_docs": checksum.Of(centralAgentDocs),
		"settings":   checksum.Of(claudeSettings),
	}

	line := term.Dim(strings.Repeat("━", 38))
	fmt.Println(line)
	fmt.Println(term.Bold("Change Detection Report"))
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
			fmt.Printf("  %s\n", term.Green(fmt.Sprintf("✓ %s (updated)", it.label)))
			hasChanges = true
		} else {
			fmt.Printf("  %s\n", term.Dim(fmt.Sprintf("- %s (no changes)", it.label)))
		}
	}

	if isSymlink(claudeMD) {
		fmt.Println("  " + term.Green("✓ Claude symlink (active)"))
		hasChanges = true
	}

	if isSymlink(copilotInstructions) {
		fmt.Println("  " + term.Green("✓ GitHub Copilot symlink (active)"))
		hasChanges = true
	}

	fmt.Println(line)

	if hasChanges {
		fmt.Println(term.BoldGreen("✓ Changes were applied successfully"))
	} else {
		fmt.Println(term.BoldGreen("✓ All files were already up to date"))
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
