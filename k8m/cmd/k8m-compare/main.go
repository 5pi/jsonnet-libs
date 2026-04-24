// compare performs a semantic YAML comparison between two directories.
// It reports missing files, extra files, and fields that differ.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: compare <golden-dir> <actual-dir>")
		os.Exit(1)
	}

	golden, actual := os.Args[1], os.Args[2]

	goldenFiles := collectYAML(golden)
	actualFiles := collectYAML(actual)

	diffs := 0

	// Files in golden but missing from actual.
	for rel := range goldenFiles {
		if _, ok := actualFiles[rel]; !ok {
			fmt.Printf("MISSING: %s\n", rel)
			diffs++
		}
	}

	// Files in actual but not in golden.
	for rel := range actualFiles {
		if _, ok := goldenFiles[rel]; !ok {
			fmt.Printf("EXTRA:   %s\n", rel)
			diffs++
		}
	}

	// Compare common files.
	for rel, goldenPath := range goldenFiles {
		actualPath, ok := actualFiles[rel]
		if !ok {
			continue
		}

		gData, err := loadYAML(goldenPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error reading golden %s: %v\n", goldenPath, err)
			diffs++
			continue
		}

		aData, err := loadYAML(actualPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error reading actual %s: %v\n", actualPath, err)
			diffs++
			continue
		}

		fieldDiffs := diffValues("", gData, aData)
		if len(fieldDiffs) > 0 {
			fmt.Printf("DIFF:    %s\n", rel)
			for _, d := range fieldDiffs {
				fmt.Printf("         %s\n", d)
			}
			diffs++
		}
	}

	if diffs == 0 {
		fmt.Printf("OK: %d files match semantically\n", len(goldenFiles))
		os.Exit(0)
	} else {
		fmt.Printf("\n%d difference(s) found\n", diffs)
		os.Exit(1)
	}
}

func collectYAML(dir string) map[string]string {
	result := make(map[string]string)
	filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if strings.HasSuffix(path, ".yaml") || strings.HasSuffix(path, ".yml") {
			rel, _ := filepath.Rel(dir, path)
			result[rel] = path
		}
		return nil
	})
	return result
}

func loadYAML(path string) (interface{}, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var v interface{}
	if err := yaml.Unmarshal(data, &v); err != nil {
		return nil, err
	}
	return v, nil
}

// diffValues recursively compares two YAML values and returns a list of diff descriptions.
func diffValues(path string, golden, actual interface{}) []string {
	var diffs []string

	// Normalize types (yaml.v3 unmarshals numbers differently than yaml safe_load).
	golden = normalize(golden)
	actual = normalize(actual)

	if reflect.DeepEqual(golden, actual) {
		return nil
	}

	gMap, gIsMap := golden.(map[string]interface{})
	aMap, aIsMap := actual.(map[string]interface{})

	if gIsMap && aIsMap {
		allKeys := unionKeys(gMap, aMap)
		sort.Strings(allKeys)
		for _, k := range allKeys {
			gv, gok := gMap[k]
			av, aok := aMap[k]
			childPath := k
			if path != "" {
				childPath = path + "." + k
			}
			if !gok {
				diffs = append(diffs, fmt.Sprintf("+ %s: %v", childPath, av))
			} else if !aok {
				diffs = append(diffs, fmt.Sprintf("- %s: %v", childPath, gv))
			} else {
				diffs = append(diffs, diffValues(childPath, gv, av)...)
			}
		}
		return diffs
	}

	gSlice, gIsSlice := golden.([]interface{})
	aSlice, aIsSlice := actual.([]interface{})

	if gIsSlice && aIsSlice {
		if len(gSlice) != len(aSlice) {
			diffs = append(diffs, fmt.Sprintf("%s: list length %d vs %d", path, len(gSlice), len(aSlice)))
			return diffs
		}
		for i := range gSlice {
			diffs = append(diffs, diffValues(fmt.Sprintf("%s[%d]", path, i), gSlice[i], aSlice[i])...)
		}
		return diffs
	}

	// If both values are strings that parse as YAML, compare them semantically.
	gStr, gIsStr := golden.(string)
	aStr, aIsStr := actual.(string)
	if gIsStr && aIsStr {
		var gParsed, aParsed interface{}
		if err1 := yaml.Unmarshal([]byte(gStr), &gParsed); err1 == nil {
			if err2 := yaml.Unmarshal([]byte(aStr), &aParsed); err2 == nil && gParsed != nil && aParsed != nil {
				return diffValues(path+"(yaml)", gParsed, aParsed)
			}
		}
	}

	diffs = append(diffs, fmt.Sprintf("%s: %v (%T) vs %v (%T)", path, golden, golden, actual, actual))
	return diffs
}

func normalize(v interface{}) interface{} {
	switch val := v.(type) {
	case map[string]interface{}:
		out := make(map[string]interface{}, len(val))
		for k, vv := range val {
			out[k] = normalize(vv)
		}
		return out
	case []interface{}:
		out := make([]interface{}, len(val))
		for i, vv := range val {
			out[i] = normalize(vv)
		}
		return out
	case int:
		return int64(val)
	case int32:
		return int64(val)
	case uint:
		return int64(val)
	case uint32:
		return int64(val)
	case uint64:
		return int64(val)
	case float32:
		return float64(val)
	}
	return v
}

func unionKeys(a, b map[string]interface{}) []string {
	seen := make(map[string]bool)
	for k := range a {
		seen[k] = true
	}
	for k := range b {
		seen[k] = true
	}
	keys := make([]string, 0, len(seen))
	for k := range seen {
		keys = append(keys, k)
	}
	return keys
}
