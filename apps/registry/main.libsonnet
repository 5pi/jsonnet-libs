local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'registry',
  namespace: 'kube-system',
  host: error 'Must define host',
  image: 'registry:2.7.1',
  storage_size: '10G',
  storage_class: 'default',
  node_selector: {},
  htpasswd: error 'Must define htpasswd',
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'registry',
      config.image,
      config.host,
      5000,
      namespace=config.namespace
    ) +
    app.withPVC(config.name, config.storage_size, '/var/lib/registry', config.storage_class) +
    {
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector),
      container+: k.core.v1.container.withEnvMap({
        REGISTRY_AUTH: 'htpasswd',
        REGISTRY_AUTH_HTPASSWD_REALM: 'Registry',
        REGISTRY_AUTH_HTPASSWD_PATH: '/auth/htpasswd',
      }),
      secret: k.core.v1.secret.new(config.name, {
        htpasswd: std.base64(config.htpasswd),
      }) + k.core.v1.secret.metadata.withNamespace(config.namespace),
    } + app.withVolumeMixin(k.core.v1.volume.fromSecret('config', config.name), '/auth'),
}
