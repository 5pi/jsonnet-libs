local app = import '../../lib/app.jsonnet';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  name: 'node-exporter',
  namespace: 'monitoring',
  port: 9100,
  uid: 1000,
  image: 'prom/node-exporter:v1.3.1',
  args: [],
};

{
  new(opts):
    local config = default_config + opts;
    {
      daemonset: k.apps.v1.daemonSet.new(config.name, containers=[
                   k.core.v1.container.new(config.name, config.image) +
                   k.core.v1.container.withArgs(['--path.rootfs=/host'] + config.args) +
                   k.core.v1.container.withVolumeMounts([
                     k.core.v1.volumeMount.new('host', '/host', true),
                   ]),
                 ]) +
                 k.apps.v1.daemonSet.metadata.withNamespace(config.namespace) +
                 k.apps.v1.daemonSet.spec.updateStrategy.rollingUpdate.withMaxUnavailable('100%') +
                 k.apps.v1.daemonSet.spec.template.spec.withHostPID(true) +
                 k.apps.v1.daemonSet.spec.template.spec.withHostNetwork(true) +
                 k.apps.v1.daemonSet.spec.template.spec.withVolumes([k.core.v1.volume.fromHostPath('host', '/')]),
    },
}
