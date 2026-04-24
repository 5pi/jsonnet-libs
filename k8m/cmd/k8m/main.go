package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/5pi/k8m/internal/engine"
	"github.com/5pi/k8m/internal/stack"
)

const usage = `k8m — prototype-chain YAML renderer for Kubernetes

Usage:
  k8m render   <stack.yaml> [-o <output-dir>]   Render all manifests in a stack
  k8m resolve  <manifest.yaml>                   Print the fully resolved manifest
  k8m trace    <manifest.yaml>                   Print field provenance (layer by layer)
  k8m check    <manifest.yaml>                   Validate: report unbound variables

Options:
  -o <dir>   Output directory for render (default: current directory)
`

func main() {
	if len(os.Args) < 3 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(1)
	}

	cmd := os.Args[1]
	target := os.Args[2]

	switch cmd {
	case "render":
		outputDir := "."
		for i := 3; i < len(os.Args)-1; i++ {
			if os.Args[i] == "-o" {
				outputDir = os.Args[i+1]
			}
		}
		if err := cmdRender(target, outputDir); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}

	case "resolve":
		if err := cmdResolve(target); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}

	case "trace":
		if err := cmdTrace(target); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}

	case "check":
		if err := cmdCheck(target); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}

	default:
		fmt.Fprintf(os.Stderr, "unknown command: %q\n\n%s", cmd, usage)
		os.Exit(1)
	}
}

func cmdRender(targetPath, outputDir string) error {
	abs, err := filepath.Abs(targetPath)
	if err != nil {
		return err
	}

	// Check if it's a stack (has $schema: stack) or a single manifest.
	data, err := os.ReadFile(abs)
	if err != nil {
		return err
	}
	var raw map[string]interface{}
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return fmt.Errorf("parsing %s: %w", targetPath, err)
	}

	resolver := engine.NewResolver()

	if raw["$schema"] == "stack" {
		return stack.Render(abs, resolver, outputDir)
	}

	// Single manifest mode.
	doc, err := resolver.Resolve(abs)
	if err != nil {
		return err
	}
	root := doc.Content[0]
	if unbound := engine.HasUnboundVariables(root); len(unbound) > 0 {
		return fmt.Errorf("%s has unbound variables: %s", targetPath, strings.Join(unbound, ", "))
	}

	outPath := filepath.Join(outputDir, filepath.Base(targetPath))
	return writeYAML(outPath, doc)
}

func cmdResolve(targetPath string) error {
	resolver := engine.NewResolver()
	doc, err := resolver.Resolve(targetPath)
	if err != nil {
		return err
	}

	root := doc.Content[0]
	if unbound := engine.HasUnboundVariables(root); len(unbound) > 0 {
		fmt.Fprintf(os.Stderr, "warning: unbound variables: %s\n", strings.Join(unbound, ", "))
	}

	return encodeYAML(os.Stdout, doc)
}

func cmdCheck(targetPath string) error {
	resolver := engine.NewResolver()
	doc, err := resolver.Resolve(targetPath)
	if err != nil {
		return err
	}

	root := doc.Content[0]
	unbound := engine.HasUnboundVariables(root)
	if len(unbound) == 0 {
		fmt.Printf("%s: OK (fully bound)\n", targetPath)
	} else {
		fmt.Printf("%s: ABSTRACT — unbound variables:\n", targetPath)
		for _, u := range unbound {
			fmt.Printf("  %s\n", u)
		}
	}
	return nil
}

func cmdTrace(targetPath string) error {
	// Trace shows the prototype chain by collecting each layer.
	layers, err := collectLayers(targetPath)
	if err != nil {
		return err
	}

	// For each field in the final resolved document, show where it came from.
	if len(layers) == 0 {
		return fmt.Errorf("no layers found")
	}

	resolver := engine.NewResolver()
	doc, err := resolver.Resolve(targetPath)
	if err != nil {
		return err
	}

	fmt.Printf("Resolved: %s\n", targetPath)
	fmt.Printf("Chain:    %s\n\n", strings.Join(layers, " → "))

	printTrace(doc.Content[0], "", layers)
	return nil
}

// collectLayers walks the $extends chain and returns file paths from leaf to root.
func collectLayers(path string) ([]string, error) {
	abs, err := filepath.Abs(path)
	if err != nil {
		return nil, err
	}

	data, err := os.ReadFile(abs)
	if err != nil {
		return nil, err
	}

	var doc yaml.Node
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return nil, err
	}

	if doc.Kind != yaml.DocumentNode || len(doc.Content) == 0 {
		return nil, fmt.Errorf("invalid document")
	}

	root := doc.Content[0]
	result := []string{abs}

	if extendsNode := engine.GetMapValue(root, "$extends"); extendsNode != nil && extendsNode.Value != "" {
		parentPath := filepath.Join(filepath.Dir(abs), extendsNode.Value)
		parentLayers, err := collectLayers(parentPath)
		if err != nil {
			return nil, err
		}
		result = append(result, parentLayers...)
	}

	return result, nil
}

func printTrace(node *yaml.Node, prefix string, layers []string) {
	if node.Kind != yaml.MappingNode {
		return
	}
	for i := 0; i < len(node.Content); i += 2 {
		key := node.Content[i].Value
		val := node.Content[i+1]
		path := key
		if prefix != "" {
			path = prefix + "." + key
		}
		if val.Kind == yaml.ScalarNode {
			fmt.Printf("  %-50s = %s\n", path, val.Value)
		} else {
			printTrace(val, path, layers)
		}
	}
}

func writeYAML(path string, doc *yaml.Node) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return encodeYAML(f, doc)
}

type writer interface {
	Write([]byte) (int, error)
}

func encodeYAML(w writer, doc *yaml.Node) error {
	var buf bytes.Buffer
	enc := yaml.NewEncoder(&buf)
	enc.SetIndent(2)
	if err := enc.Encode(doc); err != nil {
		return err
	}
	enc.Close()
	_, err := w.Write(buf.Bytes())
	return err
}
