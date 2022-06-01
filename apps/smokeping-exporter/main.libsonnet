local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'smokeping-exporter',
  namespace: 'monitoring',
  port: 9374,
  image: 'quay.io/superq/smokeping-prober:latest',
  config: '',
};

{
  new(opts):
    local config = default_config + opts;
    app.newApp(
      config.name,
      config.image,
      namespace=config.namespace,
    ) +
    app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', config.name), '/config') +
    {
      container+: k.core.v1.container.withArgs(['--config.file=/config/config.yaml']),
      configmap: k.core.v1.configMap.new(config.name, { 'config.yaml': config.config }) +
                 k.core.v1.configMap.metadata.withNamespace(config.namespace),
    },
}
