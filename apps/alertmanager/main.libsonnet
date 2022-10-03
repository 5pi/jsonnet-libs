local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'alertmanager',
  namespace: 'monitoring',
  image: 'quay.io/prometheus/alertmanager',
  node_selector: {},
  config: {
    route: {
      receiver: 'default'
    },
    receivers: [{
      name: 'default',
    }],
  },
  replicas: 1,
};

{
  new(opts):
    local config = default_config + opts;
    {
      configmap:
        k.core.v1.configMap.new(config.name, { 'config.yaml': std.manifestYamlDoc(config.config)}) +
        k.core.v1.configMap.metadata.withNamespace(config.namespace),
      container::
        k.core.v1.container.new(config.name, config.image) +
        k.core.v1.container.withArgs(
          [
            '--config.file=/etc/alertmanager/config.yaml',
            '--storage.path=/alertmanager',
          ] +
          [
            std.format('--cluster.peer=alertmanager-%d.alertmanager:9094', i)
            for i in std.range(0, config.replicas-1)
          ]
        ) +
        k.core.v1.container.withVolumeMountsMixin([
          k.core.v1.volumeMount.new('config', '/etc/alertmanager/', true),
          k.core.v1.volumeMount.new('data', '/alertmanager', false),
        ]),
      statefulset:
        k.apps.v1.statefulSet.new(config.name, config.replicas) +
        k.apps.v1.statefulSet.metadata.withNamespace(config.namespace) +
        k.apps.v1.statefulSet.spec.withServiceName(config.name) +
        k.apps.v1.statefulSet.spec.template.spec.withContainers(self.container) +
        k.apps.v1.statefulSet.spec.template.spec.withVolumes([
          k.core.v1.volume.fromConfigMap('config', self.configmap.metadata.name),
          k.core.v1.volume.fromEmptyDir('data'),
        ]),
      service:
        k.core.v1.service.new(config.name, {name: config.name}, [
          k.core.v1.servicePort.newNamed('web', 80, 9093),
          k.core.v1.servicePort.newNamed('mesh', 9094, 9094),
        ]) +
        k.core.v1.service.metadata.withNamespace(config.namespace),
    },
}
