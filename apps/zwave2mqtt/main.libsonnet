local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'zwave2mqtt',
  namespace: 'home-automation',
  port: 8091,
  image: 'robertslando/zwave2mqtt:latest',
  host: 'zwave.example.com',
  zwave_dev: '/dev/ttyACM0',
  node_selector: {},
  data_dir: '/data/zwave2mqtt',
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      config.name,
      config.image,
      config.host,
      config.port,
      namespace=config.namespace
    ) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('dev', config.zwave_dev), '/dev/ttyACM-zwave') +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('data', config.data_dir), '/usr/src/app/store') + {
      container+: k.core.v1.container.securityContext.withPrivileged(true),
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector),
    },
}
