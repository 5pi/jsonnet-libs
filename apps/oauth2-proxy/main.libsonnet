local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'oauth2-proxy',
  namespace: 'oauth2-proxy',
  port: 4180,
  image: 'quay.io/oauth2-proxy/oauth2-proxy:v7.3.0',
  host: error 'Must set host',
  client_id: error 'Must set client_id',
  client_secret: error 'Must set client_secret',
  cookie_secret: error 'Must set cookie_secret',
  client_secret_file: '/etc/oauth2-proxy/client_secret',
  node_selector: {},
  args: [],
  env: {},
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(config.name, config.image, config.host, config.port, config.namespace) + {
      secret: k.core.v1.secret.new(config.name, {
        'oauth2-proxy-client-secret': std.base64(config.client_secret),
        'oauth2-proxy-cookie-secret': std.base64(config.cookie_secret),
      }) + k.core.v1.secret.metadata.withNamespace(config.namespace),
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector),
      container+: k.core.v1.container.withEnv(k.core.v1.envVar.fromSecretRef('OAUTH2_PROXY_COOKIE_SECRET', self.secret.metadata.name, 'oauth2-proxy-cookie-secret')) +
                  k.core.v1.container.withEnvMap(config.env) +
                  k.core.v1.container.withArgs([
                    '--client-id=' + config.client_id,
                    '--client-secret-file=' + config.client_secret_file,
                    '--http-address=0.0.0.0:4180',
                    '--scope=user:email',
                  ] + config.args),
    } + app.withVolumeMixin(k.core.v1.volume.fromSecret('config', config.name) +
                            k.core.v1.volume.secret.withItems(
                              [{ key: 'oauth2-proxy-client-secret', path: 'client_secret' }]
                            ),
                            '/etc/oauth2-proxy'),
}
