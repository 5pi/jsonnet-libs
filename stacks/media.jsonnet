{
  _config:: {
    domain: error 'Must define domain',
    timezone: error 'Must define timezone',
    namespace: 'media',
    plex_env: [],
    nzbget: {
      host: 'nzbget.' + $._config.domain,
      namespace: $._config.namespace,
      config: error 'Must define nzbget.config',
      storage_class: $._config.storage_class,
      media_path: $._config.media_path,
    },
    sonarr: {
      namespace: $._config.namespace,
      host: 'sonarr.' + $._config.domain,
      storage_class: $._config.storage_class,
      media_path: $._config.media_path,
    },
    radarr: {
      namespace: $._config.namespace,
      host: 'radarr.' + $._config.domain,
      storage_class: $._config.storage_class,
      media_path: $._config.media_path,
    },
  },

  plex: (import '../apps/plex/main.jsonnet').new({
    local host = 'plex.' + $._config.domain,
    host: host,
    namespace: 'default',  // FIXME: Too lazy to move PVC right now.. $._config.namespace,
    storage_class: $._config.storage_class,
    media_path: $._config.media_path,
    env: $._config.plex_env + [
      { name: 'TZ', value: $._config.timezone },
      { name: 'ADVERTISE_IP', value: 'http://' + host + ':32400/' },
    ],
  }),

  nzbget: (import '../apps/nzbget/main.libsonnet').new($._config.nzbget),

  sonarr: (import '../apps/sonarr/main.jsonnet').new($._config.sonarr),
  radarr: (import '../apps/radarr/main.jsonnet').new($._config.radarr),
}
