package symlink

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSetup(t *testing.T) {
	t.Run("シンボリックリンクを作成する", func(t *testing.T) {
		base := t.TempDir()
		target := filepath.Join(base, "target.txt")
		link := filepath.Join(base, "link.txt")
		os.WriteFile(target, []byte("content"), 0644)

		if err := Setup(target, link); err != nil {
			t.Fatal(err)
		}

		info, err := os.Lstat(link)
		if err != nil {
			t.Fatal(err)
		}
		if info.Mode()&os.ModeSymlink == 0 {
			t.Error("シンボリックリンクではない")
		}
		resolved, _ := filepath.EvalSymlinks(link)
		expected, _ := filepath.EvalSymlinks(target)
		if resolved != expected {
			t.Errorf("リンク先が異なる: 期待=%s, 実際=%s", expected, resolved)
		}
		data, _ := os.ReadFile(link)
		if string(data) != "content" {
			t.Errorf("期待値: content, 実際: %s", string(data))
		}
	})

	t.Run("既存のシンボリックリンクを置き換える", func(t *testing.T) {
		base := t.TempDir()
		oldTarget := filepath.Join(base, "old.txt")
		newTarget := filepath.Join(base, "new.txt")
		link := filepath.Join(base, "link.txt")
		os.WriteFile(oldTarget, []byte("old"), 0644)
		os.WriteFile(newTarget, []byte("new"), 0644)
		os.Symlink(oldTarget, link)

		if err := Setup(newTarget, link); err != nil {
			t.Fatal(err)
		}

		info, _ := os.Lstat(link)
		if info.Mode()&os.ModeSymlink == 0 {
			t.Error("シンボリックリンクではない")
		}
		resolved, _ := filepath.EvalSymlinks(link)
		expected, _ := filepath.EvalSymlinks(newTarget)
		if resolved != expected {
			t.Errorf("リンク先が異なる: 期待=%s, 実際=%s", expected, resolved)
		}
		data, _ := os.ReadFile(link)
		if string(data) != "new" {
			t.Errorf("期待値: new, 実際: %s", string(data))
		}
	})

	t.Run("既存の通常ファイルを置き換えてシンボリックリンクを作成する", func(t *testing.T) {
		base := t.TempDir()
		target := filepath.Join(base, "target.txt")
		link := filepath.Join(base, "link.txt")
		os.WriteFile(target, []byte("target content"), 0644)
		os.WriteFile(link, []byte("regular file"), 0644)

		if err := Setup(target, link); err != nil {
			t.Fatal(err)
		}

		info, _ := os.Lstat(link)
		if info.Mode()&os.ModeSymlink == 0 {
			t.Error("シンボリックリンクではない")
		}
		data, _ := os.ReadFile(link)
		if string(data) != "target content" {
			t.Errorf("期待値: target content, 実際: %s", string(data))
		}
	})
}
