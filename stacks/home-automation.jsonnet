{
  _config+:: {
    domain: error 'Must define domain',
    node_selector: {},
    mqtt_node_selector: {},
    mqtt_passwd: error 'Must set mqtt_passwd',
  },
  mqtt: (import '../apps/mqtt/main.jsonnet').new({
    storage_path: '/data/mqtt',
    node_selector: $._config.mqtt_node_selector,
    passwd: $._config.mqtt_passwd,
  }),
  zwave2mqtt: (import '../apps/zwave2mqtt/main.libsonnet').new({
    host: 'zwave.' + $._config.domain,
    node_selector: $._config.node_selector,
  }),

  home_assistant: (import '../apps/home_assistant/main.libsonnet').new({
    host: 'home.' + $._config.domain,
    node_selector: $._config.node_selector,
  }),
}
