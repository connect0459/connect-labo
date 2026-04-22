package permissions

import (
	"encoding/json"
	"os"
)

func Merge(sourcePath, targetPath string) error {
	sourceData, err := os.ReadFile(sourcePath)
	if err != nil {
		return err
	}
	var sourceMap map[string]any
	if err := json.Unmarshal(sourceData, &sourceMap); err != nil {
		return err
	}

	targetMap := map[string]any{}
	if targetData, err := os.ReadFile(targetPath); err == nil {
		json.Unmarshal(targetData, &targetMap)
	}

	for k, v := range sourceMap {
		targetMap[k] = v
	}

	out, err := json.MarshalIndent(targetMap, "", "  ")
	if err != nil {
		return err
	}
	out = append(out, '\n')

	return os.WriteFile(targetPath, out, 0644)
}
