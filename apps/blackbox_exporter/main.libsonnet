local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'blackbox-exporter',
  namespace: 'monitoring',
  port: 9115,
  image: 'prom/blackbox-exporter:v0.23.0',
  config: std.parseYaml(importstr 'config.yaml'),
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
      container+:: k.core.v1.container.withArgs(["--config.file=/blackbox-exporter/config.yaml"]),
      configmap: k.core.v1.configMap.new(config.name, { 'config.yaml': std.manifestYamlDoc(config.config) }) +
                 k.core.v1.configMap.metadata.withNamespace(config.namespace),

      service: k.core.v1.service.new(config.name, self.deployment.spec.template.metadata.labels, k.core.v1.servicePort.newNamed('http', config.port, config.port)) +
               k.core.v1.service.metadata.withNamespace(self.deployment.metadata.namespace),
    },
}
