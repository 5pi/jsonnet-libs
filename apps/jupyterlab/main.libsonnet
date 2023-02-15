local app = import '../../lib/app.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'jupyter',
  namespace: 'jupyter',
  host: error 'Must define host',
  host_path: error 'Must define media_path',
  image: 'jupyter/base-notebook:2023-01-30',
  node_selector: {},
  data_path: '/data',
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'jupyter',
      config.image,
      config.host,
      8888,
      namespace=config.namespace
    ) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('data', config.data_path), '/home/jovyan') + {
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector),
      // We need to override the JUPYER_PORT env var otherwise it clashes with the automatic docker
      // env variable JUPYER_PORT.
      container+: k.core.v1.container.withEnvMap({JUPYTER_PORT: '8888'}),
    },
}
