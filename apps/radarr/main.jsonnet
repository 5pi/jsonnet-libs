local app = import '../../lib/app.jsonnet';
local containerfile = import '../../lib/containerfile.jsonnet';
local image = import '../../lib/image.jsonnet';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  name: 'radarr',
  namespace: 'default',
  host: error 'Must define host',
  media_path: error 'Must define media_path',
  mono_version: '6.12',
  version: '0.2.0.1293',
  image: 'fish/radarr:' + $.version,
  dl_url: 'https://github.com/Radarr/Radarr/releases/download/v' + $.version + '/Radarr.develop.' + $.version + '.linux.tar.gz',
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
    app.withPVC(config.name, config.storage_size, '/data', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', config.media_path), '/media') +
    app.withFSGroup(config.uid) +
    if std.extVar('include_images') == 'true' then {
      local c = [
        containerfile.from('docker.io/mono:' + config.mono_version),
        containerfile.run([
          'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/disable-sandbox',
          'apt-get -qy update',
          'apt-get -qy install curl libmediainfo0v5',
          'curl -Lsf "%s" | tar -C /opt -xzf -' % config.dl_url,
          'chmod -R +r /opt/Radarr/',
          'useradd user',
          'install -d -o user -g user /data',
        ]),
        containerfile.entrypoint(['"mono"', '"/opt/Radarr/Radarr.exe"', '"--data=/data/"']),
      ],
      image: image.fromImageName(config.name, config.image, std.join('\n', c)),
    }
    else {},
}
