local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local reloader = import '../../lib/reloader/main.libsonnet';

local prometheus_config = import 'config.libsonnet';

local default_config = {
  name: 'prometheus',
  namespace: 'prometheus',
  port: 9090,
  uid: 1000,
  image: 'prom/prometheus:v2.27.1',
  host: 'prometheus.example.com',
  external_proto: 'http',
  storage_size: '5Gi',
  storage_class: 'default',
  prometheus_config: prometheus_config,
  files: {
    'prometheus.yaml': std.manifestYamlDoc($.prometheus_config),
  },
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
    app.withPVC(config.name, config.storage_size, '/prometheus', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', config.name), '/etc/prometheus')
    {
      deployment+: k.apps.v1.deployment.spec.template.spec.withServiceAccountName(config.name) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withFsGroup(config.uid) +
                   k.apps.v1.deployment.spec.template.spec.securityContext.withRunAsUser(config.uid) +
                   k.apps.v1.deployment.spec.template.spec.withContainersMixin([reloader.volume_webhook('config', 'http://localhost:9090/-/reload')]),
      container+: k.core.v1.container.withArgs([
        '--config.file=/etc/prometheus/prometheus.yaml',
        '--log.level=info',
        '--storage.tsdb.path=/prometheus',
        '--web.enable-lifecycle',
        '--web.enable-admin-api',
        '--web.external-url=' + config.external_proto + '://' + config.host,
      ]),

      configmap: k.core.v1.configMap.new(config.name, config.files) +
                 k.core.v1.configMap.metadata.withNamespace(config.namespace),

      serviceAccount:
        k.core.v1.serviceAccount.new(config.name) +
        k.core.v1.serviceAccount.metadata.withNamespace(config.namespace),

      clusterRole:
        local coreRule = k.rbac.v1.policyRule.withApiGroups(['']) +
                         k.rbac.v1.policyRule.withResources([
                           'services',
                           'endpoints',
                           'nodes',
                           'nodes/proxy',
                           'pods',
                         ]) +
                         k.rbac.v1.policyRule.withVerbs(['get', 'list', 'watch']);

        local extensionRule = k.rbac.v1.policyRule.withApiGroups(['networking.k8s.io']) +
                              k.rbac.v1.policyRule.withResources([
                                'ingresses',
                              ]) +
                              k.rbac.v1.policyRule.withVerbs(['get', 'list', 'watch']);

        local nodeMetricsRule = k.rbac.v1.policyRule.withApiGroups(['']) +
                                k.rbac.v1.policyRule.withResources(['nodes/metrics']) +
                                k.rbac.v1.policyRule.withVerbs(['get']);

        local metricsRule = k.rbac.v1.policyRule.withNonResourceURLs('/metrics') +
                            k.rbac.v1.policyRule.withVerbs(['get']);

        local rules = [coreRule, extensionRule, nodeMetricsRule, metricsRule];

        k.rbac.v1.clusterRole.new(config.name) +
        k.rbac.v1.clusterRole.withRules(rules),

      clusterRoleBinding:

        k.rbac.v1.clusterRoleBinding.new(config.name) +
        k.rbac.v1.clusterRoleBinding.roleRef.withApiGroup('rbac.authorization.k8s.io') +
        k.rbac.v1.clusterRoleBinding.roleRef.withName(config.name) +
        k.rbac.v1.clusterRoleBinding.roleRef.withKind('ClusterRole') +
        k.rbac.v1.clusterRoleBinding.withSubjects([{ kind: 'ServiceAccount', name: config.name, namespace: config.namespace }]),
    },
}
