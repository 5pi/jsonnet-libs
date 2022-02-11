local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'fuse-device-plugin',
  namespace: 'kube-system',
  image: 'flavio/fuse-device-plugin:latest',
  device_plugin_path: '/var/lib/kubelet/device-plugins',
  node_selector: {},
};

{
  new(opts):
    local config = default_config + opts;
    local volume = k.core.v1.volume.fromHostPath('device-plugin', config.device_plugin_path);
    {
      container:: k.core.v1.container.new(config.name, config.image) +
                  k.core.v1.container.securityContext.withAllowPrivilegeEscalation(false) +
                  k.core.v1.container.securityContext.capabilities.withDrop('ALL') +
                  k.core.v1.container.withVolumeMountsMixin([
                    k.core.v1.volumeMount.new(volume.name, '/var/lib/kubelet/device-plugins', false),
                  ]),
      daemonset: k.apps.v1.daemonSet.new(config.name, self.container, { name: 'fuse-device-plugin-ds' }) +
                 k.apps.v1.daemonSet.metadata.withNamespace(config.namespace) +
                 k.apps.v1.daemonSet.spec.template.spec.withVolumes([volume]) +
                 k.apps.v1.daemonSet.spec.template.spec.withNodeSelector(config.node_selector),

    },
}
