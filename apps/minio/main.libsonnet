local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'minio',
  namespace: 'default',
  host: error 'Must define host',
  data_path: error 'Must define data_path',
  node_selector: {},
  version: 'RELEASE.2025-01-20T14-49-07Z',
  image: 'minio/minio:' + $.version,
  uid: 1000,
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      config.name,
      config.image,
      config.host,
      9001,
      namespace=config.namespace
    ) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('data', config.data_path), '/data') +
    {
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withFsGroup(config.uid) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid),
      container+: k.core.v1.container.withCommand(['minio', 'server', '/data', '--console-address', ':9001'])
    },
}
