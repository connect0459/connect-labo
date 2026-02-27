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
		label    string
		key      string
		itemType string
	}
	items := []item{
		{"AGENTS.md", "agents_md", "docs"},
		{"agent-docs/", "agent_docs", "docs"},
	}
	if settingsExists {
		items = append(items, item{"settings.json", "settings", "docs"})
	}

	type tableRow struct {
		status   string
		itemType string
		name     string
		changed  bool
	}

	var rows []tableRow
	for _, it := range items {
		if before[it.key] != after[it.key] {
			rows = append(rows, tableRow{"✓", it.itemType, it.label, true})
			hasChanges = true
		} else {
			rows = append(rows, tableRow{"-", it.itemType, it.label, false})
		}
	}
	if isSymlink(claudeMD) {
		rows = append(rows, tableRow{"✓", "symlink", "Claude", true})
		hasChanges = true
	}
	if isSymlink(copilotInstructions) {
		rows = append(rows, tableRow{"✓", "symlink", "GitHub Copilot", true})
		hasChanges = true
	}

	headers := [3]string{"Status", "Type", "Name"}
	widths := [3]int{len(headers[0]), len(headers[1]), len(headers[2])}
	for _, r := range rows {
		if w := len([]rune(r.status)); w > widths[0] {
			widths[0] = w
		}
		if w := len(r.itemType); w > widths[1] {
			widths[1] = w
		}
		if w := len([]rune(r.name)); w > widths[2] {
			widths[2] = w
		}
	}

	sep := func(left, mid, right, fill string) string {
		return left +
			strings.Repeat(fill, widths[0]+2) + mid +
			strings.Repeat(fill, widths[1]+2) + mid +
			strings.Repeat(fill, widths[2]+2) + right
	}

	fmt.Println(term.Dim(sep("┌", "┬", "┐", "─")))
	fmt.Printf("│ %-*s │ %-*s │ %-*s │\n", widths[0], headers[0], widths[1], headers[1], widths[2], headers[2])
	fmt.Println(term.Dim(sep("├", "┼", "┤", "─")))
	for _, r := range rows {
		rowLine := fmt.Sprintf("│ %-*s │ %-*s │ %-*s │",
			widths[0], r.status,
			widths[1], r.itemType,
			widths[2], r.name,
		)
		if r.changed {
			fmt.Println(term.Green(rowLine))
		} else {
			fmt.Println(term.Dim(rowLine))
		}
	}
	fmt.Println(term.Dim(sep("└", "┴", "┘", "─")))

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
