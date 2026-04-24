package engine

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// Resolver resolves manifest files, walking the $extends chain and evaluating $ref expressions.
type Resolver struct {
	cache    map[string]*yaml.Node // absPath -> resolved DocumentNode
	resolving map[string]bool       // cycle detection
}

func NewResolver() *Resolver {
	return &Resolver{
		cache:    make(map[string]*yaml.Node),
		resolving: make(map[string]bool),
	}
}

// Resolve loads, merges (walking $extends), and evaluates $ref for the given file.
// Returns a DocumentNode containing the fully resolved MappingNode.
func (r *Resolver) Resolve(path string) (*yaml.Node, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, err
	}

	if cached, ok := r.cache[absPath]; ok {
		return cached, nil
	}

	if r.resolving[absPath] {
		return nil, fmt.Errorf("cycle detected at %s", path)
	}
	r.resolving[absPath] = true
	defer func() { delete(r.resolving, absPath) }()

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil, fmt.Errorf("reading %s: %w", path, err)
	}

	var doc yaml.Node
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return nil, fmt.Errorf("parsing %s: %w", path, err)
	}

	if doc.Kind != yaml.DocumentNode || len(doc.Content) == 0 {
		return nil, fmt.Errorf("%s: empty or invalid YAML document", path)
	}

	root := doc.Content[0]
	if root.Kind != yaml.MappingNode {
		return nil, fmt.Errorf("%s: expected a YAML mapping at root", path)
	}

	// Walk $extends chain
	if extendsNode := getMapValue(root, "$extends"); extendsNode != nil && extendsNode.Value != "" {
		parentRelPath := extendsNode.Value
		parentAbsPath := filepath.Join(filepath.Dir(absPath), parentRelPath)

		parentDoc, err := r.Resolve(parentAbsPath)
		if err != nil {
			return nil, fmt.Errorf("%s extends %s: %w", path, parentRelPath, err)
		}

		parentRoot := parentDoc.Content[0]
		merged, err := mergeMapping(root, parentRoot)
		if err != nil {
			return nil, fmt.Errorf("%s: merging with parent: %w", path, err)
		}
		root = merged
	}

	// Resolve $ref expressions in-place on the merged node
	if err := r.resolveRefs(root, absPath); err != nil {
		return nil, fmt.Errorf("%s: resolving $ref: %w", path, err)
	}

	result := &yaml.Node{
		Kind:    yaml.DocumentNode,
		Content: []*yaml.Node{root},
	}

	r.cache[absPath] = result
	return result, nil
}

// resolveRefs walks the node tree and resolves all $ref scalar values in-place.
func (r *Resolver) resolveRefs(node *yaml.Node, fromFile string) error {
	switch node.Kind {
	case yaml.ScalarNode:
		if strings.HasPrefix(node.Value, "$ref ") {
			resolved, err := r.evaluateRef(node.Value, fromFile)
			if err != nil {
				return err
			}
			*node = *resolved
		}
	case yaml.MappingNode, yaml.SequenceNode:
		for _, child := range node.Content {
			if err := r.resolveRefs(child, fromFile); err != nil {
				return err
			}
		}
	}
	return nil
}

// evaluateRef parses "$ref <path> @ <field.path>" and returns the resolved node.
func (r *Resolver) evaluateRef(refStr, fromFile string) (*yaml.Node, error) {
	rest := strings.TrimPrefix(refStr, "$ref ")
	parts := strings.SplitN(rest, " @ ", 2)
	if len(parts) != 2 {
		return nil, fmt.Errorf("invalid $ref syntax (expected '$ref <path> @ <field.path>'): %q", refStr)
	}

	refRelPath := strings.TrimSpace(parts[0])
	fieldPath := strings.TrimSpace(parts[1])

	targetPath := filepath.Join(filepath.Dir(fromFile), refRelPath)
	doc, err := r.Resolve(targetPath)
	if err != nil {
		return nil, fmt.Errorf("$ref %s: %w", refRelPath, err)
	}

	return extractFieldPath(doc.Content[0], fieldPath)
}

// HasUnboundVariables returns the list of field paths still holding $variable placeholders.
func HasUnboundVariables(node *yaml.Node) []string {
	var paths []string
	collectUnbound(node, "", &paths)
	return paths
}

func collectUnbound(node *yaml.Node, prefix string, paths *[]string) {
	switch node.Kind {
	case yaml.ScalarNode:
		v := node.Value
		if strings.HasPrefix(v, "$") && !strings.HasPrefix(v, "$ref ") {
			*paths = append(*paths, fmt.Sprintf("%s=%s", prefix, v))
		}
	case yaml.MappingNode:
		for i := 0; i < len(node.Content); i += 2 {
			key := node.Content[i].Value
			val := node.Content[i+1]
			path := key
			if prefix != "" {
				path = prefix + "." + key
			}
			collectUnbound(val, path, paths)
		}
	case yaml.SequenceNode:
		for i, item := range node.Content {
			collectUnbound(item, fmt.Sprintf("%s[%d]", prefix, i), paths)
		}
	}
}
