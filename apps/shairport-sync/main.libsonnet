local app = import '../../lib/app.jsonnet';
local containerfile = import '../../lib/containerfile.jsonnet';
local image = import '../../lib/image.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'shairport-sync',
  namespace: 'media',
  version: '4.3.7',
  node_selector: {},
  image: 'mikebrady/shairport-sync:' + $.version,
//  gid: error 'Must set gid',
};

{
  new(opts):
    local config = default_config + opts;
    app.newApp(
      'shairport-sync',
      config.image,
      namespace=config.namespace
    ) + app.withVolumeMixin(k.core.v1.volume.fromHostPath('snd', '/dev/snd'), '/dev/snd') + {
      container+: k.core.v1.container.securityContext.withPrivileged(true),
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.withHostNetwork(true)
    }
}
