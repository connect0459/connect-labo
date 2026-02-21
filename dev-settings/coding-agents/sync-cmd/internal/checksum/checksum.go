package checksum

import (
	"crypto/sha256"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
)

func fileDigest(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return "NOT_EXISTS"
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "NOT_EXISTS"
	}
	return fmt.Sprintf("%x", h.Sum(nil))
}

func directoryDigest(dirPath string) string {
	info, err := os.Stat(dirPath)
	if err != nil || !info.IsDir() {
		return "NOT_EXISTS"
	}

	h := sha256.New()

	type entry struct {
		relPath string
		absPath string
	}
	var entries []entry

	filepath.WalkDir(dirPath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(dirPath, path)
		entries = append(entries, entry{relPath: rel, absPath: path})
		return nil
	})

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].relPath < entries[j].relPath
	})

	for _, e := range entries {
		h.Write([]byte(e.relPath))
		h.Write([]byte(fileDigest(e.absPath)))
	}

	return fmt.Sprintf("%x", h.Sum(nil))
}

func Of(path string) string {
	info, err := os.Stat(path)
	if err != nil {
		return "NOT_EXISTS"
	}
	if info.IsDir() {
		return directoryDigest(path)
	}
	return fileDigest(path)
}
