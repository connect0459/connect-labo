package dirsync

import (
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
)

func Sync(src, dst string) error {
	if info, err := os.Stat(dst); err == nil && info.IsDir() {
		if err := deleteExtraFiles(src, dst); err != nil {
			return err
		}
		if err := deleteEmptyDirs(dst); err != nil {
			return err
		}
	}

	return copyTree(src, dst)
}

func CopyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	info, err := in.Stat()
	if err != nil {
		return err
	}

	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, info.Mode())
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

func deleteExtraFiles(src, dst string) error {
	return filepath.WalkDir(dst, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(dst, path)
		srcPath := filepath.Join(src, rel)
		if _, err := os.Stat(srcPath); os.IsNotExist(err) {
			return os.Remove(path)
		}
		return nil
	})
}

func deleteEmptyDirs(dst string) error {
	var dirs []string
	filepath.WalkDir(dst, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && path != dst {
			dirs = append(dirs, path)
		}
		return nil
	})

	sort.Slice(dirs, func(i, j int) bool {
		return len(filepath.SplitList(dirs[i])) > len(filepath.SplitList(dirs[j]))
	})

	for _, d := range dirs {
		entries, err := os.ReadDir(d)
		if err != nil {
			continue
		}
		if len(entries) == 0 {
			os.Remove(d)
		}
	}
	return nil
}

func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		target := filepath.Join(dst, rel)

		if d.IsDir() {
			return os.MkdirAll(target, 0755)
		}

		return CopyFile(path, target)
	})
}
