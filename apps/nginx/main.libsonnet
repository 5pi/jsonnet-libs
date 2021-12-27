local app = import '../../lib/app.jsonnet';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  name: 'nginx',
  namespace: 'nginx',,
  port: 8080,
  image: 'nginx:1.21.1-alpine',
  host: 'nginx.example.com',
  node_selector: {},
  config: '''
  location / {
      auth_basic           "closed site";
      auth_basic_user_file conf/htpasswd;
  }
  ''',
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
    app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', config.name), '/etc/nginx') +
    {
      configmap: k.core.v1.configMap.new(config.name, { 'nginx.conf': config.config }) +
                 k.core.v1.configMap.metadata.withNamespace(config.namespace),
    },
}
