local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'zigbee2mqtt',
  namespace: 'home-automation',
  port: 8080,
  image: 'koenkk/zigbee2mqtt:latest',
  host: 'zigbee.example.com',
  storage_size: '500Mi',
  storage_class: 'default',
  zigbee_dev: error 'Must set zigbee_dev',
  node_selector: {},
  uid: 65534, // 'nobody'
  gid: 20, // 'dialout'
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
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('dev', config.zigbee_dev), '/dev/ttyACM0') +
    app.withPVC(config.name, config.storage_size, '/app/data', config.storage_class) + {
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsGroup(config.gid),
      container+: k.core.v1.container.securityContext.withPrivileged(true),
    },
}
