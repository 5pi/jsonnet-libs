local app = import '../../lib/app.jsonnet';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  name: 'blackbox-exporter',
  namespace: 'monitoring',
  port: 9115,
  image: 'prom/blackbox-exporter:v0.16.0',
  config: std.manifestYamlDoc(import 'config.libsonnet'),
};

{
  new(opts):
    local config = default_config + opts;
    app.newApp(
      config.name,
      config.image,
      namespace=config.namespace,
    ) +
    app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', config.name), '/blackbox-exporter') +
    {
      configmap: k.core.v1.configMap.new(config.name, { 'config.yaml': config.config }) +
                 k.core.v1.configMap.metadata.withNamespace(config.namespace),
    },
}
