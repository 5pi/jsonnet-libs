local zfs_localpv = import '../apps/zfs-localpv/main.libsonnet';
local k = import 'k.libsonnet';

{
  _config:: {
    pools: [],
  },
  operator: zfs_localpv,
  storage_classes: {
    [pool.name]:
      k.storage.v1.storageClass.new(pool.name) +
      k.storage.v1.storageClass.withAllowVolumeExpansion(true) +
      k.storage.v1.storageClass.withProvisioner('zfs.csi.openebs.io') +
      k.storage.v1.storageClass.withParameters({
        recordsize: '4k',
        compression: 'off',
        dedup: 'off',
        thinprovision: 'yes',
        fstype: 'zfs',
        poolname: if std.objectHas(pool, 'pool_name') then pool.pool_name else pool.name,
      }) +
      if std.objectHas(pool, 'hostname') then
        k.storage.v1.storageClass.withAllowedTopologies([{
          matchLabelExpressions: [{
            key: 'kubernetes.io/hostname',
            values: [pool.hostname],
          }],
        }])
      else {}
    for pool in $._config.pools
  },
}
