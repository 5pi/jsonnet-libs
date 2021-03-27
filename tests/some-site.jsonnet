local domain = 'example.com';
local fpl = import 'main.libsonnet';

local zfs = fpl.stacks.zfs {
  _config+: {
    pools: ['mirror', 'stripe-nvme'],
  },
};

local media = fpl.stacks.media {
  _config+: {
    domain: domain,
    storage_class: 'zfs-stripe-nvme',
    media_path: '/pool-mirror/media',

    usenet: {
      server1_username: 'user',
      server1_password: 'password',
    },

    timezone: 'Europe/Berlin',
    plex_env: [{ name: 'PLEX_CLAIM', value: 'foo' }],
  },
};

local monitoring = fpl.stacks.monitoring {
  _config+:: {
    prometheus+: {
      external_domain: 'prometheus.' + domain,
      storage_class: 'zfs-stripe-nvme',
    },
    grafana+: {
      external_domain: 'grafana.' + domain,
    },
  },
};

local home_automation = fpl.stacks['home-automation'] {
  _config+: {
    domain: domain,
    node_selector: { 'kubernetes.io/hostname': 'rpi-living' },
    mqtt_node_selector: { 'kubernetes.io/hostname': 'openwrt' },
  },
};

local ingress_nginx = fpl.apps['ingress-nginx'].new({
  host_mode: true,
  node_selector: { 'kubernetes.io/hostname': 'openwrt' },
});

fpl.lib.site.render({
  zfs: zfs,
  ingress: {
    ingress_nginx: ingress_nginx,
  },
  monitoring: monitoring,
  media: media,
  home_automation: home_automation,
})
