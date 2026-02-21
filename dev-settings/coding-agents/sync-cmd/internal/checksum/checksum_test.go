package checksum

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFileDigest(t *testing.T) {
	t.Run("ファイルのSHA256チェックサムを計算できる", func(t *testing.T) {
		dir := t.TempDir()
		file := filepath.Join(dir, "hello.txt")
		os.WriteFile(file, []byte("hello"), 0644)

		result := fileDigest(file)

		if len(result) != 64 {
			t.Errorf("チェックサムの長さが64ではない: %d", len(result))
		}
	})

	t.Run("同じ内容のファイルは同じチェックサムを返す", func(t *testing.T) {
		dir := t.TempDir()
		fileA := filepath.Join(dir, "a.txt")
		fileB := filepath.Join(dir, "b.txt")
		os.WriteFile(fileA, []byte("same content"), 0644)
		os.WriteFile(fileB, []byte("same content"), 0644)

		if fileDigest(fileA) != fileDigest(fileB) {
			t.Error("同じ内容のファイルが異なるチェックサムを返した")
		}
	})

	t.Run("異なる内容のファイルは異なるチェックサムを返す", func(t *testing.T) {
		dir := t.TempDir()
		fileA := filepath.Join(dir, "a.txt")
		fileB := filepath.Join(dir, "b.txt")
		os.WriteFile(fileA, []byte("content A"), 0644)
		os.WriteFile(fileB, []byte("content B"), 0644)

		if fileDigest(fileA) == fileDigest(fileB) {
			t.Error("異なる内容のファイルが同じチェックサムを返した")
		}
	})

	t.Run("存在しないファイルはNOT_EXISTSを返す", func(t *testing.T) {
		dir := t.TempDir()
		result := fileDigest(filepath.Join(dir, "nonexistent.txt"))
		if result != "NOT_EXISTS" {
			t.Errorf("期待値: NOT_EXISTS, 実際: %s", result)
		}
	})
}

func TestDirectoryDigest(t *testing.T) {
	t.Run("ディレクトリのチェックサムを計算できる", func(t *testing.T) {
		dir := t.TempDir()
		os.WriteFile(filepath.Join(dir, "file.txt"), []byte("content"), 0644)

		result := directoryDigest(dir)

		if len(result) != 64 {
			t.Errorf("チェックサムの長さが64ではない: %d", len(result))
		}
	})

	t.Run("ファイル追加でチェックサムが変わる", func(t *testing.T) {
		dir := t.TempDir()
		os.WriteFile(filepath.Join(dir, "file.txt"), []byte("content"), 0644)
		before := directoryDigest(dir)

		os.WriteFile(filepath.Join(dir, "new.txt"), []byte("new"), 0644)
		after := directoryDigest(dir)

		if before == after {
			t.Error("ファイル追加後もチェックサムが変わらなかった")
		}
	})

	t.Run("同じ構造のディレクトリは同じチェックサムを返す", func(t *testing.T) {
		base := t.TempDir()
		dirA := filepath.Join(base, "a")
		dirB := filepath.Join(base, "b")
		for _, d := range []string{dirA, dirB} {
			os.MkdirAll(d, 0755)
			os.WriteFile(filepath.Join(d, "file.txt"), []byte("same"), 0644)
			sub := filepath.Join(d, "sub")
			os.MkdirAll(sub, 0755)
			os.WriteFile(filepath.Join(sub, "nested.txt"), []byte("nested"), 0644)
		}

		if directoryDigest(dirA) != directoryDigest(dirB) {
			t.Error("同じ構造のディレクトリが異なるチェックサムを返した")
		}
	})

	t.Run("存在しないディレクトリはNOT_EXISTSを返す", func(t *testing.T) {
		dir := t.TempDir()
		result := directoryDigest(filepath.Join(dir, "nonexistent"))
		if result != "NOT_EXISTS" {
			t.Errorf("期待値: NOT_EXISTS, 実際: %s", result)
		}
	})
}

func TestOf(t *testing.T) {
	t.Run("ファイルパスを渡すとファイルチェックサムを返す", func(t *testing.T) {
		dir := t.TempDir()
		file := filepath.Join(dir, "file.txt")
		os.WriteFile(file, []byte("content"), 0644)

		if Of(file) != fileDigest(file) {
			t.Error("Of がファイルチェックサムと一致しない")
		}
	})

	t.Run("ディレクトリパスを渡すとディレクトリチェックサムを返す", func(t *testing.T) {
		dir := t.TempDir()
		os.WriteFile(filepath.Join(dir, "file.txt"), []byte("content"), 0644)

		if Of(dir) != directoryDigest(dir) {
			t.Error("Of がディレクトリチェックサムと一致しない")
		}
	})

	t.Run("存在しないパスはNOT_EXISTSを返す", func(t *testing.T) {
		dir := t.TempDir()
		result := Of(filepath.Join(dir, "nonexistent"))
		if result != "NOT_EXISTS" {
			t.Errorf("期待値: NOT_EXISTS, 実際: %s", result)
		}
	})
}
