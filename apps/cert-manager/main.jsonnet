local cm = import '../../contrib/cert-manager/main.json';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  args: [],
};

local acme_issuer(email, class, env='staging') = {
  local endpoint = if env == 'production' then 'acme-v02' else 'acme-staging-v02',
  apiVersion: 'cert-manager.io/v1',
  kind: 'ClusterIssuer',
  metadata: {
    name: 'letsencrypt-' + env,
  },
  spec: {
    acme: {
      email: email,
      privateKeySecretRef: {
        name: 'letsencrypt-' + env + '-account-key',
      },
      server: 'https://' + endpoint + '.api.letsencrypt.org/directory',
      solvers: [
        {
          http01: {
            ingress: {
              class: class,
            },
          },
        },
      ],
    },
  },
};

local withCertManagerTLS(issuer) = {
  ingress+: k.networking.v1.ingress.spec.withTls(
    k.networking.v1.ingressTLS.withHosts($.ingress_rule.host) +
    k.networking.v1.ingressTLS.withSecretName($.ingress_rule.host)
  ) + k.networking.v1.ingress.metadata.withAnnotations({
    'cert-manager.io/cluster-issuer': issuer,
  }),
};

{
  new(user_config):
    local config = default_config + user_config;
    cm {
      'cert-manager-deployment'+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                cm['cert-manager-deployment'].spec.template.spec.containers[0] {
                  args+: config.args,
                },
              ],
            },
          },
        },
      },
    },
  acme_issuer:: acme_issuer,
  withCertManagerTLS:: withCertManagerTLS,
}
