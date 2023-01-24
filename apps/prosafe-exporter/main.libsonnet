local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'prosafe-exporter',
  namespace: 'monitoring',
  version: 'latest',
  node_selector: {},
  image: 'fish/prosafe_exporter:' + $.version,
  port: 9493,
};

 //+ app.withVolumeMixin(k.core.v1.volume.fromHostPath('syslog', '/dev/log'), '/dev/log')
{
  new(opts):
    local config = default_config + opts;
    app.newApp(
      config.name,
      config.image,
      namespace=config.namespace
    ) + {
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.withHostNetwork(true),
      service: k.core.v1.service.new(config.name, self.deployment.spec.template.metadata.labels, k.core.v1.servicePort.newNamed('http', config.port, config.port)) +
          k.core.v1.service.metadata.withNamespace(self.deployment.metadata.namespace),
    }
}
