local app = import '../../lib/app.jsonnet';
local image = import '../../lib/image.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'radarr',
  namespace: 'default',
  host: error 'Must define host',
  media_path: error 'Must define media_path',
  version: '4.7.5.7809-ls187',
  image: 'lscr.io/linuxserver/radarr:'+ $.version,
  storage_size: '500Mi',
  storage_class: 'default',
  uid: 1000,  // FIXME: This is hardcoded in the image
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
    ) +
    app.withPVC(config.name, config.storage_size, '/config', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', config.media_path), '/media') +
    app.withFSGroup(config.uid)
}
