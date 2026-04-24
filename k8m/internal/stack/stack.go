package stack

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/5pi/k8m/internal/engine"
)

type Stack struct {
	Path      string
	Name      string
	Manifests []ManifestRef
}

type ManifestRef struct {
	// Path relative to the stack file's directory.
	Path string
}

// Parse reads a stack YAML file and returns its manifest list.
// Stack files must have $schema: stack.
func Parse(path string) (*Stack, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var raw map[string]interface{}
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parsing stack %s: %w", path, err)
	}

	if raw["$schema"] != "stack" {
		return nil, fmt.Errorf("%s: not a stack file ($schema must be 'stack', got %v)", path, raw["$schema"])
	}

	// Derive stack name from file name without extension.
	base := filepath.Base(path)
	name := strings.TrimSuffix(base, filepath.Ext(base))

	s := &Stack{
		Path: path,
		Name: name,
	}

	manifests, _ := raw["manifests"].([]interface{})
	for _, m := range manifests {
		mMap, ok := m.(map[string]interface{})
		if !ok {
			continue
		}
		mPath, _ := mMap["path"].(string)
		if mPath != "" {
			s.Manifests = append(s.Manifests, ManifestRef{Path: mPath})
		}
	}

	return s, nil
}

// Render resolves every manifest in the stack and writes them to outputDir.
// Output path: <outputDir>/<stackName>/<appDir>/<manifestFile>
// where appDir is the name of the directory containing the manifest file.
func Render(stackPath string, resolver *engine.Resolver, outputDir string) error {
	s, err := Parse(stackPath)
	if err != nil {
		return err
	}

	stackDir := filepath.Dir(stackPath)

	for _, ref := range s.Manifests {
		manifestAbsPath := filepath.Join(stackDir, ref.Path)

		doc, err := resolver.Resolve(manifestAbsPath)
		if err != nil {
			return fmt.Errorf("resolving %s: %w", ref.Path, err)
		}

		root := doc.Content[0]
		if unbound := engine.HasUnboundVariables(root); len(unbound) > 0 {
			return fmt.Errorf("%s has unbound variables: %s", ref.Path, strings.Join(unbound, ", "))
		}

		outPath := outputPath(outputDir, s.Name, ref.Path)
		if err := writeManifest(outPath, doc); err != nil {
			return fmt.Errorf("writing %s: %w", outPath, err)
		}
	}

	return nil
}

// outputPath computes <outputDir>/<stackName>/<appDir>/<file>.
// refPath is the manifest path as declared in the stack (relative to stack file).
func outputPath(outputDir, stackName, refPath string) string {
	// Normalize: strip any leading ../ components, take last two path elements.
	clean := filepath.Clean(refPath)
	parts := strings.Split(clean, string(filepath.Separator))

	var appDir, manifestFile string
	switch len(parts) {
	case 0:
		appDir, manifestFile = stackName, "manifest.yaml"
	case 1:
		appDir, manifestFile = stackName, parts[0]
	default:
		appDir = parts[len(parts)-2]
		manifestFile = parts[len(parts)-1]
	}

	return filepath.Join(outputDir, stackName, appDir, manifestFile)
}

func writeManifest(path string, doc *yaml.Node) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}

	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	enc := yaml.NewEncoder(f)
	enc.SetIndent(2)
	defer enc.Close()

	return enc.Encode(doc)
}
