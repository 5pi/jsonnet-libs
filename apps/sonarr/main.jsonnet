local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';
local app = import '../../lib/app.jsonnet';

local default_config = {
  name: 'sonarr',
  namespace: 'default',
  host: error 'Must define host',
  media_path: error 'Must define media_path',
  image: 'fish/sonarr@sha256:66dfdb71890123758b154f922825288b272531be759d27f5ca2860a9cebdd2b8',
  storage_size: '500Mi',
  storage_class: 'default',
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'sonarr',
      config.image,
      config.host,
      8989,
      namespace=config.namespace
    ) +
    app.withPVC(config.name, config.storage_size, '/data', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', config.media_path), '/media'),
}
