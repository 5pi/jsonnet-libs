local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';
local node_mixins = import 'node-mixin/mixin.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',
    prometheus+:: {
      node_selector: {},
    },
    node_exporter+:: {},
    scrape_interval_seconds: 30,
  },
  node_mixins:: node_mixins {
    _config+:: {
      rateInterval: $._config.scrape_interval_seconds * 3 + 's',  // Rate should have 3 data points available
    },
  },
  kubernetes_mixins:: (import 'kubernetes-mixin/mixin.libsonnet') + {
    _config+:: {
      kubeSchedulerSelector: 'kubernetes_name="kube-scheduler"',
      kubeControllerManagerSelector: 'kubernetes_name="kube-controller-manager"',
    },
  },

  prometheus+: (import '../apps/prometheus/main.libsonnet').new($._config.prometheus {
    namespace: $._config.namespace,
    files+: {
      'kubernetes.recording.rules.yaml': std.manifestYamlDoc($.kubernetes_mixins.prometheusRules),
      'kubernetes.alerting.rules.yaml': std.manifestYamlDoc($.kubernetes_mixins.prometheusAlerts),

      'node.recording.rules.yaml': std.manifestYamlDoc($.node_mixins.prometheusRules),
      'node.alerting.rules.yaml': std.manifestYamlDoc($.node_mixins.prometheusAlerts),
    },
    prometheus_config+: {
      global: { scrape_interval: $._config.scrape_interval_seconds + 's' },
    },
  }),

  blackbox_exporter: (import '../apps/blackbox_exporter/main.libsonnet').new({
    namespace: $._config.namespace,
  }),

  node_exporter: (import '../apps/node_exporter/main.libsonnet').new({
    namespace: $._config.namespace,
  } + $._config.node_exporter),

  _grafana:: (import 'grafana/grafana.libsonnet') +
             {
               _config+:: {
                 namespace: 'monitoring',
                 versions+:: {
                   grafana: '7.5.4',
                 },
                 prometheus+:: {
                   serviceName: 'prometheus',
                 },
                 grafana+:: {
                   dashboards: ($.kubernetes_mixins + $.node_mixins).grafanaDashboards,
                   container: {
                     requests: { memory: '80Mi' },
                     limits: { memory: '80Mi' },
                   },
                   config: {
                     sections: {
                       'auth.anonymous': {
                         enabled: true,
                       },
                     },
                   },
                 },
               },
             },


  grafana: $._grafana.grafana {
    dashboardDefinitions:: super.dashboardDefinitions,
    ingress: k.networking.v1.ingress.new('grafana') +
             k.networking.v1.ingress.metadata.withNamespace($._config.namespace) +
             k.networking.v1.ingress.spec.withRules([
               k.networking.v1.ingressRule.withHost($._config.grafana.external_domain) +
               k.networking.v1.ingressRule.http.withPaths([
                 k.networking.v1.httpIngressPath.withPath('/') +
                 k.networking.v1.httpIngressPath.withPathType('Prefix') +
                 k.networking.v1.httpIngressPath.backend.service.withName('grafana') +
                 k.networking.v1.httpIngressPath.backend.service.port.withNumber(3000),
               ]),
             ]),
  } + {
    [dashboard.metadata.name]: dashboard
    for dashboard in $._grafana.grafana.dashboardDefinitions
  },

  kube_state_metrics: (import 'kube-state-metrics/kube-state-metrics.libsonnet') + {
    name: 'kube-state-metrics',
    namespace: $._config.namespace,
    version: 'v2.0.0',
    image: 'k8s.gcr.io/kube-state-metrics/kube-state-metrics:' + self.version,
  },
}
