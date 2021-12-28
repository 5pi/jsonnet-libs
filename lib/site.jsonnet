{
  render(site): {
    [path]: std.manifestYamlDoc(site[path])
    for path in std.objectFields(site)
  },

  build(site): {
    [stack + '/' + app + '/' + manifest + '.yaml']: site[stack][app][manifest]
    for stack in std.objectFields(site)
    for app in std.objectFields(site[stack])  // stack fields are apps
    for manifest in std.objectFields(site[stack][app])  // app fields are manifests
  },
}
