# k8m — prototype-chain YAML renderer for Kubernetes

A new config format that sits between raw YAML and a full templating system.
The format adds exactly **six concepts** on top of plain YAML:

| Concept | Syntax | Where |
|---------|--------|-------|
| Declare schema | `$schema: k8s/apps/v1/Deployment` | Root manifests only |
| Inherit from parent | `$extends: path/to/file.yaml` | Any manifest |
| Unbound field | `$fieldname` | Any value position |
| Delete inherited field | `~remove` | Any value position |
| Reference another file's field | `$ref path @ field.path` | Any value position |
| Group manifests | `$schema: stack` + `manifests:` | Stack files |

## Commands

```
k8m render   <stack.yaml> [-o <output-dir>]   Render all manifests in a stack
k8m resolve  <manifest.yaml>                   Print the fully resolved manifest
k8m trace    <manifest.yaml>                   Print field provenance (layer by layer)
k8m check    <manifest.yaml>                   Validate: report unbound variables
```

## Build

```
cd k8m
go install ./...
```

Installs: `k8m`, `k8m-compare`, `k8m-convert`.

## Testing

Run `./test-k8m` from the repo root. It renders all stacks into `tests-k8m/some-site/`
and asserts `git diff` is clean.

Set `COMPARE_JSONNET=1` to also verify semantic equivalence with the jsonnet golden output:

```
COMPARE_JSONNET=1 ./test-k8m
```

## Config layout

```
configs/
  base/          Abstract base manifests (variables as $name, $namespace, etc.)
  apps/          Concrete app manifests extending base (or fully static)
  stacks/        Stack files listing manifests per stack
```
