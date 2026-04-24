// convert rewrites a "quoted-everything" YAML file (as output by jsonnet's
// std.manifestYamlDoc) to clean, unquoted YAML using gopkg.in/yaml.v3.
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: convert <src.yaml> <dst.yaml>")
		os.Exit(1)
	}

	src, dst := os.Args[1], os.Args[2]

	data, err := os.ReadFile(src)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read %s: %v\n", src, err)
		os.Exit(1)
	}

	var node yaml.Node
	if err := yaml.Unmarshal(data, &node); err != nil {
		fmt.Fprintf(os.Stderr, "parse %s: %v\n", src, err)
		os.Exit(1)
	}

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "mkdir: %v\n", err)
		os.Exit(1)
	}

	f, err := os.Create(dst)
	if err != nil {
		fmt.Fprintf(os.Stderr, "create %s: %v\n", dst, err)
		os.Exit(1)
	}
	defer f.Close()

	// Strip forced-quote styles so output is clean YAML.
	stripStyles(&node)

	enc := yaml.NewEncoder(f)
	enc.SetIndent(2)
	defer enc.Close()

	if err := enc.Encode(&node); err != nil {
		fmt.Fprintf(os.Stderr, "encode: %v\n", err)
		os.Exit(1)
	}
}

func stripStyles(node *yaml.Node) {
	if node.Kind == yaml.ScalarNode {
		// Remove double-quote style; let the encoder decide the best representation.
		if node.Style == yaml.DoubleQuotedStyle {
			node.Style = 0
		}
	}
	for _, child := range node.Content {
		stripStyles(child)
	}
}
