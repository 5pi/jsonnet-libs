package engine

import (
	"fmt"
	"strings"

	"gopkg.in/yaml.v3"
)

// GetMapValue returns the value node for the given key in a MappingNode, or nil.
// Exported for use by the CLI trace command.
func GetMapValue(node *yaml.Node, key string) *yaml.Node {
	return getMapValue(node, key)
}

// getMapValue is the internal implementation.
func getMapValue(node *yaml.Node, key string) *yaml.Node {
	if node.Kind != yaml.MappingNode {
		return nil
	}
	for i := 0; i < len(node.Content); i += 2 {
		if node.Content[i].Value == key {
			return node.Content[i+1]
		}
	}
	return nil
}

// extractFieldPath navigates a dot-separated field path and returns the node.
// e.g. "spec.template.metadata.labels"
func extractFieldPath(node *yaml.Node, path string) (*yaml.Node, error) {
	if node.Kind == yaml.DocumentNode {
		if len(node.Content) == 0 {
			return nil, fmt.Errorf("empty document")
		}
		node = node.Content[0]
	}

	parts := strings.Split(path, ".")
	current := node

	for _, part := range parts {
		if current.Kind != yaml.MappingNode {
			return nil, fmt.Errorf("expected mapping when navigating %q, got kind %d", part, current.Kind)
		}
		next := getMapValue(current, part)
		if next == nil {
			return nil, fmt.Errorf("field %q not found in mapping", part)
		}
		current = next
	}

	return current, nil
}
