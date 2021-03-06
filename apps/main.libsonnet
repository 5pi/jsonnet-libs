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
}
