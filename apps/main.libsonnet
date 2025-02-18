{
  blackbox_exporter: import 'blackbox_exporter/main.jsonnet',
  home_assistant: import 'home_assistant/main.libsonnet',
  'ingress-nginx': import 'ingress-nginx/main.jsonnet',
  mqtt: import 'mqtt/main.jsonnet',
  node_exporter: import 'node_exporter/main.jsonnet',
  nzbget: import 'nzbget/main.jsonnet',
  plex: import 'plex/main.jsonnet',
  prometheus: import 'prometheus/main.jsonnet',
  radarr: import 'radarr/main.jsonnet',
  sonarr: import 'sonarr/main.jsonnet',
  'zfs-localpv': import 'zfs-localpv/main.jsonnet',
  zwave2mqtt: import 'zwave2mqtt/main.libsonnet',
  cert_manager: import 'cert-manager/main.jsonnet',
  fuse_device_plugin: import 'fuse-device-plugin/main.jsonnet',
  registry: import 'registry/main.libsonnet',
  oauth2_proxy: import 'oauth2-proxy/main.libsonnet',
  jupyterlab: import 'jupyterlab/main.libsonnet',
  k8s_webhook_handler: import 'k8s-webhook-handler/main.libsonnet',
  argo: import 'argo/main.jsonnet',
  k8s_image_controller: import 'k8s-image-controller/main.libsonnet',
  rclone: import 'rclone/main.libsonnet',
  spotifyd: import 'spotifyd/main.libsonnet',
  smokeping_exporter: import 'smokeping-exporter/main.libsonnet',
  shairport_sync: import 'shairport-sync/main.libsonnet',
  pulseaudio: import 'pulseaudio/main.libsonnet',
  alertmanager: import 'alertmanager/main.libsonnet',
  minio: import 'minio/main.libsonnet',
  prosafe_exporter: import 'prosafe-exporter/main.libsonnet',
  zigbee2mqtt: import 'zigbee2mqtt/main.libsonnet',
  zwave_js_ui: import 'zwave-js-ui/main.libsonnet',
}
