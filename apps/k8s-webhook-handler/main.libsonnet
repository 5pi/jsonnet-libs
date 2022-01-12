local app = import '../../lib/app.jsonnet';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  name: 'k8s-webhook-handler',
  namespace: 'ci',
  host: error 'Must define host',
  webhook_secret: error 'Must define secret',
  github_username: '',
  github_token: error 'Must define github_token',
  image: 'registry.d.42o.de/k8s-webhook-handler:d658524534',
  uid: 1000,
  ca_certificates_path: '/etc/ssl/certs',
  node_selector: {},
  rbac_rules: [],
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'k8s-webhook-handler',
      config.image,
      config.host,
      8080,
      namespace=config.namespace
    ) + {
      service_account: k.core.v1.serviceAccount.new(config.name) +
                       k.core.v1.serviceAccount.metadata.withNamespace(config.namespace),
      rbac_role: k.rbac.v1.role.new(config.name) +
                 k.rbac.v1.role.metadata.withNamespace(config.namespace) +
                 k.rbac.v1.role.withRules(config.rbac_rules),
      rbac_role_binding: k.rbac.v1.roleBinding.new(config.name) +
                         k.rbac.v1.roleBinding.metadata.withNamespace(config.namespace) +
                         k.rbac.v1.roleBinding.bindRole(self.rbac_role) +
                         k.rbac.v1.roleBinding.withSubjects(k.rbac.v1.subject.fromServiceAccount(self.service_account)),
      secret: k.core.v1.secret.new(config.name, {
        'github-username': std.base64(config.github_username),
        'webhook-secret': std.base64(config.webhook_secret),
        'github-token': std.base64(config.github_token),
      }) + k.core.v1.secret.metadata.withNamespace(config.namespace),
      container+: k.core.v1.container.withEnv([
        k.core.v1.envVar.fromSecretRef('WEBHOOK_SECRET', self.secret.metadata.name, 'webhook-secret'),
        k.core.v1.envVar.fromSecretRef('GITHUB_TOKEN', self.secret.metadata.name, 'github-token'),
      ]),
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid) +
                   k.apps.v1.deployment.spec.template.spec.withServiceAccountName(self.service_account.metadata.name),
    } + app.withVolumeMixin(k.core.v1.volume.fromHostPath('cacerts', config.ca_certificates_path), '/etc/ssl/certs'),
}
