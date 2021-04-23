local app = import '../../lib/app.jsonnet';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  name: 'nzbget',
  namespace: 'default',
  port: 6789,
  image: 'fish/nzbget:v21.0',
  host: error 'Must specify host',
  media_path: error 'Must specify media_path',
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
    app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', config.name + '-config'), '/etc/nzbget') +
    {
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid),
      container+: k.core.v1.container.withArgs(['-s', '--configfile=/etc/nzbget/nzbget.conf']),
      configmap: k.core.v1.configMap.new(config.name + '-config', { 'nzbget.conf': config.config }) +
                 k.core.v1.configMap.metadata.withNamespace(config.namespace),
    },
}
