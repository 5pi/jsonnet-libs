package engine

import (
	"gopkg.in/yaml.v3"
)

const removeToken = "~remove"

// mergeNodes deep-merges child over parent. Child values win; mappings and named
// sequences are merged recursively; all other sequences replace the parent.
func mergeNodes(child, parent *yaml.Node) (*yaml.Node, error) {
	if child.Kind == yaml.MappingNode && parent.Kind == yaml.MappingNode {
		return mergeMapping(child, parent)
	}
	if child.Kind == yaml.SequenceNode && parent.Kind == yaml.SequenceNode {
		return mergeSequence(child, parent)
	}
	// Scalar or mismatched kinds: child wins outright.
	return child, nil
}

// mergeMapping merges child mapping over parent mapping.
// Keys with value "~remove" are dropped. $extends and $schema are stripped.
func mergeMapping(child, parent *yaml.Node) (*yaml.Node, error) {
	result := &yaml.Node{Kind: yaml.MappingNode}

	// Index child entries by key (value is at i+1).
	childValIdx := make(map[string]int, len(child.Content)/2)
	for i := 0; i < len(child.Content); i += 2 {
		childValIdx[child.Content[i].Value] = i + 1
	}

	childUsed := make(map[string]bool, len(child.Content)/2)

	// Iterate parent keys, applying child overrides where present.
	for i := 0; i < len(parent.Content); i += 2 {
		pKey := parent.Content[i]
		pVal := parent.Content[i+1]
		key := pKey.Value

		if key == "$extends" || key == "$schema" {
			continue
		}

		if vi, ok := childValIdx[key]; ok {
			childUsed[key] = true
			cVal := child.Content[vi]

			if isRemove(cVal) {
				continue // tombstone: omit this key
			}

			merged, err := mergeNodes(cVal, pVal)
			if err != nil {
				return nil, err
			}
			result.Content = append(result.Content, pKey, merged)
		} else {
			result.Content = append(result.Content, pKey, pVal)
		}
	}

	// Append child-only keys (not present in parent).
	for i := 0; i < len(child.Content); i += 2 {
		cKey := child.Content[i]
		cVal := child.Content[i+1]
		key := cKey.Value

		if key == "$extends" || key == "$schema" {
			continue
		}

		if !childUsed[key] && !isRemove(cVal) {
			result.Content = append(result.Content, cKey, cVal)
		}
	}

	return result, nil
}

// mergeSequence merges two sequences. If both have items with a "name" key
// (Kubernetes strategic merge patch convention), items are merged by name.
// Otherwise the child sequence replaces the parent entirely.
func mergeSequence(child, parent *yaml.Node) (*yaml.Node, error) {
	if !sequenceHasNamedItems(parent) || !sequenceHasNamedItems(child) {
		return child, nil
	}

	// Build parent index by name value.
	parentByName := make(map[string]*yaml.Node, len(parent.Content))
	parentOrder := make([]string, 0, len(parent.Content))
	for _, item := range parent.Content {
		if item.Kind == yaml.MappingNode {
			if nameNode := getMapValue(item, "name"); nameNode != nil {
				n := nameNode.Value
				parentByName[n] = item
				parentOrder = append(parentOrder, n)
			}
		}
	}

	result := &yaml.Node{Kind: yaml.SequenceNode}
	usedParent := make(map[string]bool, len(parentByName))

	for _, cItem := range child.Content {
		if cItem.Kind == yaml.MappingNode {
			if nameNode := getMapValue(cItem, "name"); nameNode != nil {
				name := nameNode.Value
				if pItem, ok := parentByName[name]; ok {
					usedParent[name] = true
					merged, err := mergeMapping(cItem, pItem)
					if err != nil {
						return nil, err
					}
					result.Content = append(result.Content, merged)
					continue
				}
			}
		}
		result.Content = append(result.Content, cItem)
	}

	// Append parent items that had no matching child item.
	for _, name := range parentOrder {
		if !usedParent[name] {
			result.Content = append(result.Content, parentByName[name])
		}
	}

	return result, nil
}

func isRemove(node *yaml.Node) bool {
	return node.Kind == yaml.ScalarNode && node.Value == removeToken
}

func sequenceHasNamedItems(seq *yaml.Node) bool {
	for _, item := range seq.Content {
		if item.Kind == yaml.MappingNode && getMapValue(item, "name") != nil {
			return true
		}
	}
	return false
}
