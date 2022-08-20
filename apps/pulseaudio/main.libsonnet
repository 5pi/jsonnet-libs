local app = import '../../lib/app.jsonnet';
local containerfile = import '../../lib/containerfile.jsonnet';
local image = import '../../lib/image.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'pulseaudio',
  namespace: 'media',
  alpine_version: '3.16',
  image: 'fish/pulseaudio:latest',
  dev_snd_gid: '29',
  config: {
    'native-tcp-anonymous.pa': |||
      .fail
      load-module module-alsa-sink
      load-module module-alsa-source
      load-module module-zeroconf-publish
      load-module module-native-protocol-tcp auth-anonymous=1
    |||,
  },
};

{
  new(opts):
    local config = default_config + opts;
    app.newApp(
      config.name,
      config.image,
      namespace=config.namespace
    ) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('snd', '/dev/snd'), '/dev/snd') +
    app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', config.name), '/etc/pulse/system.pa.d') + {
      container+: k.core.v1.container.securityContext.withPrivileged(true) +
                  k.core.v1.container.withEnvMap({
                    PA_GID: config.dev_snd_gid,
                  }),

      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.withHostNetwork(true),
      configmap: k.core.v1.configMap.new(config.name, config.config) +
                 k.core.v1.configMap.metadata.withNamespace(config.namespace),
    },
}
