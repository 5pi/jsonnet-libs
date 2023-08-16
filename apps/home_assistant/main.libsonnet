local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'home-assistant',
  namespace: 'home-assistant',
  port: 8123,
  image: 'homeassistant/home-assistant:2023.8',
  host: 'home.example.com',
  data_path: '/data/home-assistant',
  node_selector: {},
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'home-assistant',
      config.image,
      config.host,
      8123,
      namespace=config.namespace
    ) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('config', config.data_path), '/config') +
    {
      container+: k.core.v1.container.withCommand(['python3', '-m', 'homeassistant', '--config', '/config']) +
                  k.core.v1.container.mixin.securityContext.withPrivileged(true) +
                  k.core.v1.container.mixin.livenessProbe.withInitialDelaySeconds(600) +
                  k.core.v1.container.mixin.livenessProbe.httpGet.withPort(8123),
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.withHostNetwork(true),
    },
}
