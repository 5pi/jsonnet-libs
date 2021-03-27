# jsonnet-lib
jsonnet libraries to generate Kubernetes manifests and Dockerfiles.

The focus here is more personal and homelab infrastructure but it should be
adoptable to production environments.

# Status
- Experimental, everything is subject to change
- Don't expect this to work for your setup out the box..
- ..but the experiment is to see if it's possible to make this work for your
  personal setup as well so...
- PRs to make it work for your use cases are very welcome!

# Usage
- Home infrastructure: https://github.com/5pi-home/home

# Conventions
- `_config` is used for configuration

## Stack
- set of applications fullfilling a single purpose
- yields a map with application name and application

Examples:
- Monitoring: `./stacks/monitoring.jsonnet`
- Home Automation: `./stacks/home-automation.jsonnet`
- Minecraft

## Application
- a service / application and all dependencies like database setup, ingress
  configuration, configmaps

Examples:
- Prometheus: `./apps/prometheus`
- home-assistant: `./apps/home_assistant`


# Example hierarchy
```
<5pi-home> +--[zfs]---(zfs-local-pv)
           |    +---- (zfs-storage-classes)
           +--[monitoring]--(prometheus)
           |       +--------(grafana)
           |       +--------(node-exporter)
           |       +--------(blackbox-exporter)
           +--[home-automation]--(home-assistant)
                   +-------------(zwave2mqtt)
```
- `<>` site
- `[]` stack
- `()` app

# Open Questions
- Use mixins or functions for lib
- Do these abstractions make sense?
- Is it okay best practice wise to use 'half a stack' by hiding apps?
- Name of this lib causes:
`WARN: cannot link 'github.com/5pi/jsonnet-libs' to '/Users/johannes_ziemke/private/home/vendor/jsonnet-libs', because package
'github.com/grafana/jsonnet-libs' already uses that name. The absolute import still works`
