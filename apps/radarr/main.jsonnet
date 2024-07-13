local app = import '../../lib/app.jsonnet';
local image = import '../../lib/image.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'radarr',
  namespace: 'default',
  host: error 'Must define host',
  media_path: error 'Must define media_path',
  version: '5.7.0.8882-ls228',
  image: 'lscr.io/linuxserver/radarr:'+ $.version,
  storage_size: '500Mi',
  storage_class: 'default',
  uid: 1000,
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'radarr',
      config.image,
      config.host,
      7878,
      namespace=config.namespace
    ) + {
    container+:     k.core.v1.container.withCommand(['/app/radarr/bin/Radarr', '--data=/config/']),
    deployment+:    k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid) +
                    k.apps.v1.deployment.spec.template.spec.dnsConfig.withOptions([{name: "ndots", value: "1"}]) // Set ndots to fix dns resolution on musl
    } +
    app.withPVC(config.name, config.storage_size, '/config', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', config.media_path), '/media') +
    app.withFSGroup(config.uid)
}
