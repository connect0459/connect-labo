package permissions

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestMerge(t *testing.T) {
	t.Run("ソースのpermissionsをターゲットにマージする", func(t *testing.T) {
		base := t.TempDir()
		source := filepath.Join(base, "source.json")
		target := filepath.Join(base, "target.json")
		os.WriteFile(source, []byte(`{"permissions": {"allow": ["read"]}}`), 0644)
		os.WriteFile(target, []byte(`{}`), 0644)

		if err := Merge(source, target); err != nil {
			t.Fatal(err)
		}

		result := readJSON(t, target)
		perms := result["permissions"].(map[string]any)
		allow := perms["allow"].([]any)
		if len(allow) != 1 || allow[0] != "read" {
			t.Errorf("期待値: [read], 実際: %v", allow)
		}
	})

	t.Run("ターゲットが存在しない場合は新規作成する", func(t *testing.T) {
		base := t.TempDir()
		source := filepath.Join(base, "source.json")
		target := filepath.Join(base, "target.json")
		os.WriteFile(source, []byte(`{"permissions": {"allow": ["write"]}}`), 0644)

		if err := Merge(source, target); err != nil {
			t.Fatal(err)
		}

		result := readJSON(t, target)
		perms := result["permissions"].(map[string]any)
		allow := perms["allow"].([]any)
		if len(allow) != 1 || allow[0] != "write" {
			t.Errorf("期待値: [write], 実際: %v", allow)
		}
	})

	t.Run("ターゲットの既存permissionsを上書きする", func(t *testing.T) {
		base := t.TempDir()
		source := filepath.Join(base, "source.json")
		target := filepath.Join(base, "target.json")
		os.WriteFile(source, []byte(`{"permissions": {"allow": ["new"]}}`), 0644)
		os.WriteFile(target, []byte(`{"permissions": {"allow": ["old"]}}`), 0644)

		if err := Merge(source, target); err != nil {
			t.Fatal(err)
		}

		result := readJSON(t, target)
		perms := result["permissions"].(map[string]any)
		allow := perms["allow"].([]any)
		if len(allow) != 1 || allow[0] != "new" {
			t.Errorf("期待値: [new], 実際: %v", allow)
		}
	})

	t.Run("ターゲットのpermissions以外のフィールドを保持する", func(t *testing.T) {
		base := t.TempDir()
		source := filepath.Join(base, "source.json")
		target := filepath.Join(base, "target.json")
		os.WriteFile(source, []byte(`{"permissions": {"allow": []}}`), 0644)
		os.WriteFile(target, []byte(`{"theme": "dark", "permissions": {"allow": ["old"]}}`), 0644)

		if err := Merge(source, target); err != nil {
			t.Fatal(err)
		}

		result := readJSON(t, target)
		if result["theme"] != "dark" {
			t.Errorf("theme が保持されていない: %v", result["theme"])
		}
		perms := result["permissions"].(map[string]any)
		allow := perms["allow"].([]any)
		if len(allow) != 0 {
			t.Errorf("期待値: [], 実際: %v", allow)
		}
	})

	t.Run("ソースにpermissionsがない場合は空オブジェクトをマージする", func(t *testing.T) {
		base := t.TempDir()
		source := filepath.Join(base, "source.json")
		target := filepath.Join(base, "target.json")
		os.WriteFile(source, []byte(`{"other": "value"}`), 0644)
		os.WriteFile(target, []byte(`{}`), 0644)

		if err := Merge(source, target); err != nil {
			t.Fatal(err)
		}

		result := readJSON(t, target)
		perms, ok := result["permissions"].(map[string]any)
		if !ok {
			t.Fatal("permissions がマップではない")
		}
		if len(perms) != 0 {
			t.Errorf("期待値: {}, 実際: %v", perms)
		}
	})
}

func readJSON(t *testing.T, path string) map[string]any {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var result map[string]any
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	return result
}
