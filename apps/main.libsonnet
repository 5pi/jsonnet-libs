{
  blackbox_exporter: import 'blackbox_exporter/main.jsonnet',
  home_assistant: import 'home_assistant/main.jsonnet',
  'ingress-nginx': import 'ingress-nginx/main.jsonnet',
  mqtt: import 'mqtt/main.jsonnet',
  node_exporter: import 'node_exporter/main.jsonnet',
  nzbget: import 'nzbget/main.jsonnet',
  plex: import 'plex/main.jsonnet',
  prometheus: import 'prometheus/main.jsonnet',
  radarr: import 'radarr/main.jsonnet',
  sonarr: import 'sonarr/main.jsonnet',
  'zfs-localpv': import 'zfs-localpv/main.jsonnet',
  zwave2mqtt: import 'zwave2mqtt/main.jsonnet',
  cert_manager: import 'cert-manager/main.jsonnet',
  fuse_device_plugin: import 'fuse-device-plugin/main.jsonnet',
  registry: import 'registry/main.libsonnet',
  oauth2_proxy: import 'oauth2-proxy/main.libsonnet',
  jupyterlab: import 'jupyterlab/main.libsonnet',
  k8s_webhook_handler: import 'k8s-webhook-handler/main.libsonnet',
  argo: import 'argo/main.jsonnet',
  k8s_image_controller: import 'k8s-image-controller/main.libsonnet',
}
