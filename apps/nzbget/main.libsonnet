local app = import '../../lib/app.jsonnet';
local containerfile = import '../../lib/containerfile.jsonnet';
local image = import '../../lib/image.jsonnet';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  name: 'nzbget',
  namespace: 'default',
  port: 6789,
  debian_version: 'bullseye',
  version: '21.1',
  dl_url: 'https://github.com/nzbget/nzbget/releases/download/v' + $.version + '/nzbget-' + $.version + '-bin-linux.run',
  image: 'fish/nzbget:v21.1',
  host: error 'Must specify host',
  media_path: error 'Must specify media_path',
  cacert_path: '/etc/ssl/certs/ca-certificates.crt',
  storage_class: 'default',
  storage_size: '100Gi',
  uid: 1000,
  node_selector: {},
  config: '',
  ingress_max_body_size: '500m',
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      config.name,
      config.image,
      config.host,
      config.port,
      namespace=config.namespace
    ) +
    app.withPVC(config.name, config.storage_size, '/nzbget/downloads', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', config.media_path), '/media') +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('cacerts', config.cacert_path), '/etc/ssl/certs/ca-certificates.crt') +
    app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', config.name + '-config'), '/etc/nzbget') +
    app.withFSGroup(config.uid) +
    {
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid),
      container+: k.core.v1.container.withArgs(['-s', '--configfile=/etc/nzbget/nzbget.conf']),
      ingress+: k.networking.v1.ingress.metadata.withAnnotations({ 'nginx.ingress.kubernetes.io/proxy-body-size': config.ingress_max_body_size }),
      configmap: k.core.v1.configMap.new(config.name + '-config', { 'nzbget.conf': config.config }) +
                 k.core.v1.configMap.metadata.withNamespace(config.namespace),
    } +
    if std.extVar('include_images') == 'true' then {
      local c = [
        containerfile.from('debian:' + config.debian_version),
        containerfile.run([
          'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/disable-sandbox',
          'apt-get -qy update',
          'apt-get -qy install curl',
          "curl -sLo /tmp/nzbget.run '%s'" % config.dl_url,
          'sh /tmp/nzbget.run',
          'rm /tmp/nzbget.run',
          'echo user:x:1000:100:user:/tmp:/bin/sh >> /etc/passwd',
        ]),
        containerfile.entrypoint(['"/nzbget/nzbget"']),
      ],
      image: image.fromImageName(config.name, config.image, std.join('\n', c)),
    }
    else {},

}
