local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'jellyfin',
  namespace: 'default',
  host: error 'Must define host',
  media_path: error 'Must define media_path',
  image: 'lscr.io/linuxserver/jellyfin:10.11.11ubu2404-ls38',
  storage_size: '1Gi',
  storage_class: 'default',
  uid: 1000,
  env: [],
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'jellyfin',
      config.image,
      config.host,
      8096,
      namespace=config.namespace
    ) +
    app.withPVC(config.name, config.storage_size, '/config', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', config.media_path), '/media') +
    app.withVolumeMixin(k.core.v1.volume.fromEmptyDir('cache'), '/config/cache') +
    app.withFSGroup(config.uid) + {
      container+: k.core.v1.container.withEnv(config.env),
      deployment+: k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid),
    },
}
