local k = import 'k.libsonnet';

local newApp(name, image, namespace='default') = {
  container:: k.core.v1.container.new(name, image),
  deployment: k.apps.v1.deployment.new(name, containers=[$.container]) +
              k.apps.v1.deployment.metadata.withNamespace(namespace),
};

local withWeb(host, containerPort) = {
  _port:: containerPort,

  service: k.core.v1.service.new($.deployment.metadata.name, $.deployment.spec.template.metadata.labels, k.core.v1.servicePort.newNamed('http', $._port, $._port)) +
           k.core.v1.service.metadata.withNamespace($.deployment.metadata.namespace),

  ingress_rule:: k.networking.v1.ingressRule.withHost(host) +
                 k.networking.v1.ingressRule.http.withPaths([
                   k.networking.v1.httpIngressPath.withPath('/') +
                   k.networking.v1.httpIngressPath.withPathType('Prefix') +
                   k.networking.v1.httpIngressPath.backend.service.withName($.service.metadata.name) +
                   k.networking.v1.httpIngressPath.backend.service.port.withNumber($._port),
                 ]),
  ingress: k.networking.v1.ingress.new($.deployment.metadata.name) +
           k.networking.v1.ingress.metadata.withNamespace($.deployment.metadata.namespace) +
           k.networking.v1.ingress.spec.withRules([$.ingress_rule]),
};

local newWebApp(name, image, host, containerPort, namespace='default') =
  newApp(name, image, namespace) +
  withWeb(host, containerPort);

local withVolumeMountsMixin(volume, volumeMounts) = {
  deployment+: k.apps.v1.deployment.spec.template.spec.withVolumesMixin(volume),
  container+: k.core.v1.container.withVolumeMountsMixin(volumeMounts),

};

local withVolumeMixin(volume, mountPath, readOnly=false) = withVolumeMountsMixin(volume, [k.core.v1.volumeMount.new(volume.name, mountPath, readOnly)]);

local withPVC(name, size, mountPath, class='default') = {
  pvc: k.core.v1.persistentVolumeClaim.new($.deployment.metadata.name) +
       k.core.v1.persistentVolumeClaim.metadata.withNamespace($.deployment.metadata.namespace) +
       k.core.v1.persistentVolumeClaim.spec.withAccessModes('ReadWriteOnce') +
       k.core.v1.persistentVolumeClaim.spec.resources.withRequests({ storage: size }) +
       k.core.v1.persistentVolumeClaim.spec.withStorageClassName(class),
} + withVolumeMixin(k.core.v1.volume.fromPersistentVolumeClaim(name, name), mountPath) + {
  deployment+: k.apps.v1.deployment.spec.strategy.withType('Recreate'),
};

local withFSGroup(fsGroup) = {
  deployment+: k.apps.v1.deployment.spec.template.spec.securityContext.withFsGroup(fsGroup),
};

{
  newApp:: newApp,
  newWebApp:: newWebApp,

  withVolumeMixin:: withVolumeMixin,
  withVolumeMountsMixin:: withVolumeMountsMixin,
  withWeb:: withWeb,
  withPVC:: withPVC,
  withFSGroup:: withFSGroup,
}
