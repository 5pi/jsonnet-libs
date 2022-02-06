{
  new(name, registry, repository, tag, containerfile, builderName='podman'): {
    apiVersion: 'imagecontroller.5pi.de/v1alpha1',
    kind: 'Image',
    metadata: {
      name: name,
    },
    spec: {
      builderName: builderName,
      registry: registry,
      repository: repository,
      tag: tag,
      containerfile: containerfile,
    },
  },
  // registry.d.42o.de/repository:tag
  fromImageName(name, imageName, containerfile):
    local rn = std.splitLimit(imageName, '/', 1);
    local rt = std.splitLimit(rn[1], ':', 1);
    $.new(name, rn[0], rt[0], rt[1], containerfile),
}
