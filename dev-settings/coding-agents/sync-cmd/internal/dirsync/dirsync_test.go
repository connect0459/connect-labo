package dirsync

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSync(t *testing.T) {
	t.Run("ソースからデスティネーションにファイルをコピーする", func(t *testing.T) {
		base := t.TempDir()
		src := filepath.Join(base, "src")
		dst := filepath.Join(base, "dst")
		os.MkdirAll(src, 0755)
		os.WriteFile(filepath.Join(src, "file.txt"), []byte("content"), 0644)

		if err := Sync(src, dst); err != nil {
			t.Fatal(err)
		}

		data, err := os.ReadFile(filepath.Join(dst, "file.txt"))
		if err != nil {
			t.Fatal(err)
		}
		if string(data) != "content" {
			t.Errorf("期待値: content, 実際: %s", string(data))
		}
	})

	t.Run("ネストされたディレクトリ構造を正しく同期する", func(t *testing.T) {
		base := t.TempDir()
		src := filepath.Join(base, "src")
		dst := filepath.Join(base, "dst")
		sub := filepath.Join(src, "sub", "deep")
		os.MkdirAll(sub, 0755)
		os.WriteFile(filepath.Join(sub, "nested.txt"), []byte("deep content"), 0644)

		if err := Sync(src, dst); err != nil {
			t.Fatal(err)
		}

		data, err := os.ReadFile(filepath.Join(dst, "sub", "deep", "nested.txt"))
		if err != nil {
			t.Fatal(err)
		}
		if string(data) != "deep content" {
			t.Errorf("期待値: deep content, 実際: %s", string(data))
		}
	})

	t.Run("既存ファイルを上書きする", func(t *testing.T) {
		base := t.TempDir()
		src := filepath.Join(base, "src")
		dst := filepath.Join(base, "dst")
		os.MkdirAll(src, 0755)
		os.MkdirAll(dst, 0755)
		os.WriteFile(filepath.Join(src, "file.txt"), []byte("updated"), 0644)
		os.WriteFile(filepath.Join(dst, "file.txt"), []byte("old"), 0644)

		if err := Sync(src, dst); err != nil {
			t.Fatal(err)
		}

		data, _ := os.ReadFile(filepath.Join(dst, "file.txt"))
		if string(data) != "updated" {
			t.Errorf("期待値: updated, 実際: %s", string(data))
		}
	})

	t.Run("ソースに存在しないデスティネーションのファイルを削除する", func(t *testing.T) {
		base := t.TempDir()
		src := filepath.Join(base, "src")
		dst := filepath.Join(base, "dst")
		os.MkdirAll(src, 0755)
		os.MkdirAll(dst, 0755)
		os.WriteFile(filepath.Join(src, "keep.txt"), []byte("keep"), 0644)
		os.WriteFile(filepath.Join(dst, "keep.txt"), []byte("old"), 0644)
		os.WriteFile(filepath.Join(dst, "remove.txt"), []byte("should be removed"), 0644)

		if err := Sync(src, dst); err != nil {
			t.Fatal(err)
		}

		if _, err := os.Stat(filepath.Join(dst, "keep.txt")); err != nil {
			t.Error("keep.txt が存在しない")
		}
		if _, err := os.Stat(filepath.Join(dst, "remove.txt")); err == nil {
			t.Error("remove.txt が削除されていない")
		}
	})

	t.Run("ソースに存在しない空ディレクトリを削除する", func(t *testing.T) {
		base := t.TempDir()
		src := filepath.Join(base, "src")
		dst := filepath.Join(base, "dst")
		os.MkdirAll(src, 0755)
		os.MkdirAll(dst, 0755)
		os.MkdirAll(filepath.Join(dst, "empty_dir"), 0755)

		if err := Sync(src, dst); err != nil {
			t.Fatal(err)
		}

		if _, err := os.Stat(filepath.Join(dst, "empty_dir")); err == nil {
			t.Error("empty_dir が削除されていない")
		}
	})

	t.Run("デスティネーションが存在しない場合でも動作する", func(t *testing.T) {
		base := t.TempDir()
		src := filepath.Join(base, "src")
		dst := filepath.Join(base, "dst")
		os.MkdirAll(src, 0755)
		os.WriteFile(filepath.Join(src, "file.txt"), []byte("content"), 0644)

		if err := Sync(src, dst); err != nil {
			t.Fatal(err)
		}

		data, err := os.ReadFile(filepath.Join(dst, "file.txt"))
		if err != nil {
			t.Fatal(err)
		}
		if string(data) != "content" {
			t.Errorf("期待値: content, 実際: %s", string(data))
		}
	})
}
