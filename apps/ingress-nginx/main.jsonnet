local ingress = import '../../contrib/ingress-nginx/main.json';
local k = import 'k.libsonnet';
local default_config = {
  host_mode: false,  // host_mode disables the service and runs ingress-nginx on host networking
  node_selector: error 'Must define node_selector when using host_mode',
  service_type: 'NodePort',
};

{
  new(user_config):
    local config = default_config + user_config;
    ingress {
      'ingress-nginx-controller-deployment'+:
        k.apps.v1.deployment.spec.template.spec.withNodeSelectorMixin(config.node_selector),
      'ingress-nginx-controller-service'+:
        k.core.v1.service.spec.withType(config.service_type),
    } +
    if config.host_mode then {
      'ingress-nginx-controller-service':: super['ingress-nginx-controller-service'],
      'ingress-nginx-controller-deployment'+:
        k.apps.v1.deployment.spec.strategy.withType('Recreate') +
        k.apps.v1.deployment.spec.template.spec.withHostNetwork(true) +
        k.apps.v1.deployment.spec.template.spec.withDnsPolicy('ClusterFirstWithHostNet'),
    } else {},
}
