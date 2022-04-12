local k = import 'k.libsonnet';

{
  _config+:: {
    image_repo: 'jimmidyson/configmap-reload',
    version: '0.3.0',
  },
  volume_webhook(volume_name, webhook_url):
    local image = $._config.image_repo + ':v' + $._config.version;
    local volume_mount = k.core.v1.volumeMount.new(volume_name, '/volume');

    k.core.v1.container.new('reloader', image) +
    k.core.v1.container.withArgs([
      '-volume-dir',
      '/volume',
      '-webhook-url',
      webhook_url,
    ]) +
    k.core.v1.container.withVolumeMounts([volume_mount]),
}
