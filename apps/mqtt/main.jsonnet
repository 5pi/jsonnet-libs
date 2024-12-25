local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'mqtt',
  namespace: 'home-automation',
  node_selector: {},
  storage_path: '',
  avahi_path: '',
  image: 'eclipse-mosquitto:2.0.20',
  passwd: error 'Must set passwd',
};

{
  new(opts)::
    local config = default_config + opts;
    app.newApp(
      config.name,
      config.image,
      namespace=config.namespace
    ) + (
      if config.storage_path != '' then
        app.withVolumeMixin(k.core.v1.volume.fromHostPath('data', config.storage_path), '/mosquitto/data') else
        {}
    ) + (
      if config.avahi_path != '' then
        app.withVolumeMixin(k.core.v1.volume.fromHostPath('avahi-services', config.avahi_path), '/etc/avahi/services') else
        {}
    )
    + app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', config.name), '/mosquitto/config') +
    app.withVolumeMixin(
      k.core.v1.volume.fromSecret('passwd', config.name) +
      k.core.v1.volume.secret.withDefaultMode(std.parseOctal("600"))
      , '/mosquitto/passwd') +
    app.withFSGroup(1883) +
    {
      container+: k.core.v1.container.withPorts([
                    k.core.v1.containerPort.new(1883),
                  ]) +
                  if config.avahi_path != '' then
                    k.core.v1.container.lifecycle.postStart.exec.withCommand([
                      '/bin/sh',
                      '-euc',
                      |||
                        cat << EOF > /etc/avahi/services/mqtt.service
                        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
                        <service-group>
                         <name replace-wildcards="yes">Mosquitto MQTT server on %h</name>
                          <service>
                           <type>_mqtt._tcp</type>
                           <port>1883</port>
                           <txt-record>info=Publish, Publish! Read all about it! mqtt.org</txt-record>
                          </service>
                        </service-group>
                      |||,
                    ]) +
                    k.core.v1.container.lifecycle.preStop.exec.withCommand(['rm', '/etc/avahi/services/mqtt.service']) else {},
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector),
      configmap: k.core.v1.configMap.new(config.name, {
        'mosquitto.conf': |||
          log_dest stdout
          persistence %s
          persistence_location %s
          listener 1883
          allow_anonymous false
          password_file /mosquitto/passwd/passwd
        ||| % [if config.storage_path != '' then 'true' else 'false', config.storage_path],
      }) + k.core.v1.configMap.metadata.withNamespace(config.namespace),
      secret: k.core.v1.secret.new(config.name, {
        'passwd': std.base64(config.passwd),
      }) + k.core.v1.secret.metadata.withNamespace(config.namespace),
      service:
        k.core.v1.service.new(config.name, {name: config.name}, [
          k.core.v1.servicePort.newNamed('mqtt', 1883, 1883),
        ]) +
        k.core.v1.service.metadata.withNamespace(config.namespace),
      service_external:
        k.core.v1.service.new(config.name + '-external', {name: config.name}, [
          k.core.v1.servicePort.newNamed('mqtt', 1883, 1883),
        ]) +
        k.core.v1.service.metadata.withNamespace(config.namespace) +
        k.core.v1.service.spec.withType('LoadBalancer'),
    },
}
