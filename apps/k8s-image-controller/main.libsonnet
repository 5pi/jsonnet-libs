local controller = import 'github.com/discordianfish/k8s-image-controller/deploy/deploy.libsonnet';

local default_config = {};

{
  new(opts):
    local config = default_config + opts;
    controller {
      _config+: config,
    },
}
