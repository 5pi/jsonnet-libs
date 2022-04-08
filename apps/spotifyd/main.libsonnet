local app = import '../../lib/app.jsonnet';
local containerfile = import '../../lib/containerfile.jsonnet';
local image = import '../../lib/image.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'spotifyd',
  namespace: 'media',
  version: '0.3.3',
  node_selector: {},
  debian_version: 'bullseye',
  image: 'fish/spotifyd:'+$.version,
  dl_url: 'https://github.com/Spotifyd/spotifyd/releases/download/v'+$.version+'/spotifyd-linux-armv6-slim.tar.gz',
  uid: 1000,
  gid: error 'Must set gid',
};

 //+ app.withVolumeMixin(k.core.v1.volume.fromHostPath('syslog', '/dev/log'), '/dev/log')
{
  new(opts):
    local config = default_config + opts;
    app.newApp(
      'spotifyd',
      config.image,
      namespace=config.namespace
    ) + app.withVolumeMixin(k.core.v1.volume.fromHostPath('snd', '/dev/snd'), '/dev/snd') + {
      container+: k.core.v1.container.securityContext.withPrivileged(true),
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.withHostNetwork(true) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsGroup(config.gid)
    } +
    if std.extVar('include_images') == 'true' then {
      local c = [
        containerfile.from('docker.io/debian:' + config.debian_version),
        containerfile.run([
          'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/disable-sandbox',
          'apt-get -qy update',
          'apt-get -qy install curl libasound2',
          'curl -Lsf "%s" | tar -C /usr/bin -xzf -' % config.dl_url,
          'useradd user',
        ]),
        containerfile.user('user'),
        containerfile.entrypoint(['"/usr/src/spotifyd/spotifyd"', '"--no-daemon"']),
      ],
      image: image.fromImageName(config.name, config.image, std.join('\n', c)),
    }
    else {},
}
