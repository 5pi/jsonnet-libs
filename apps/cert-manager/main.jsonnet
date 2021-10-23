local cm = import '../../contrib/cert-manager/main.json';

local default_config = {
  email: 'user@example.com',
  ingress_class: 'nginx',
  args: [],
};

local issuer(email, class) = {
  apiVersion: 'cert-manager.io/v1',
  kind: 'ClusterIssuer',
  metadata: {
    name: 'letsencrypt-staging',
  },
  spec: {
    acme: {
      email: email,
      privateKeySecretRef: {
        name: 'letsencrypt-staging-account-key',
      },
      server: 'https://acme-staging-v02.api.letsencrypt.org/directory',
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

{
  new(user_config):
    local config = default_config + user_config;
    cm {
      'cluster-issuer-letsencrypt-staging': issuer(config.email, config.ingress_class),
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
}
