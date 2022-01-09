local argo = import '../../contrib/argo/main.json';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local default_config = {
  cli_image: 'quay.io/argoproj/argocli:v3.2.6',
  controller_image: 'quay.io/argoproj/workflow-controller:v3.2.6',
  namespace: 'argo',
  node_selector: {},
  config: {},
};

{
  new(user_config):
    local config = default_config + user_config;
    argo {
      'argo-server-deployment'+:
        {
          spec+: {
            template+: {
              spec+: {
                containers: [argo['argo-server-deployment'].spec.template.spec.containers[0] +
                             k.core.v1.container.withImage(config.cli_image)],
              },
            },
          },
        } +
        k.apps.v1.deployment.metadata.withNamespace(config.namespace) +
        k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector),
      'workflow-controller-deployment'+:
        {
          spec+: {
            template+: {
              spec+: {
                containers: [argo['workflow-controller-deployment'].spec.template.spec.containers[0] +
                             k.core.v1.container.withImage(config.controller_image)],
              },
            },
          },
        } +
        k.apps.v1.deployment.metadata.withNamespace(config.namespace) +
        k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector),
      'argo-binding-rolebinding'+: k.rbac.v1.roleBinding.metadata.withNamespace(config.namespace),
      'argo-role-role'+: k.rbac.v1.role.metadata.withNamespace(config.namespace),
      'argo-server-service'+: k.core.v1.service.metadata.withNamespace(config.namespace),
      'argo-server-serviceaccount'+: k.core.v1.serviceAccount.metadata.withNamespace(config.namespace),
      'argo-serviceaccount'+: k.core.v1.serviceAccount.metadata.withNamespace(config.namespace),
      'workflow-controller-configmap-configmap'+:
        k.core.v1.configMap.metadata.withNamespace(config.namespace) +
        k.core.v1.configMap.withData(config.config),
      'workflow-controller-metrics-service'+: k.core.v1.service.metadata.withNamespace(config.namespace),
    },
}
