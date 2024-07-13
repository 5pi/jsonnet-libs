local app = import '../../lib/app.jsonnet';
local containerfile = import '../../lib/containerfile.jsonnet';
local image = import '../../lib/image.jsonnet';
local k = import 'k.libsonnet';

local default_config = {
  name: 'rclone',
  namespace: 'default',
  port: 5572,
  debian_version: 'bullseye',
  version: '1.57.0',
  dl_url: 'https://downloads.rclone.org/v' + $.version + '/rclone-v' + $.version + '-linux-amd64.zip',
  image: error 'Must specify image',
  host: error 'Must specify host',
  data_path: error 'Must specify data_path',
  args: [],
  uid: 1000,
  node_selector: {},
  jobs: [],
};

{
  new(opts):
    local config = default_config + opts;
    {
      [job.name + '_cronjob']: k.batch.v1.cronJob.new(config.name + '-' + job.name) +
                               k.batch.v1.cronJob.metadata.withNamespace(config.namespace) +
                               k.batch.v1.cronJob.spec.withSchedule(job.schedule) +
                               k.batch.v1.cronJob.spec.jobTemplate.spec.template.spec.securityContext.withRunAsUser(config.uid) +
                               k.batch.v1.cronJob.spec.jobTemplate.spec.template.spec.withNodeSelector(config.node_selector) +
                               k.batch.v1.cronJob.spec.jobTemplate.spec.template.spec.withVolumes([k.core.v1.volume.fromHostPath('data', config.data_path)]) +
                               k.batch.v1.cronJob.spec.jobTemplate.spec.template.spec.withRestartPolicy('OnFailure') +
                               k.batch.v1.cronJob.spec.jobTemplate.spec.template.spec.withContainers([
                                 k.core.v1.container.new('job', config.image) +
                                 k.core.v1.container.withArgs(config.args + job.args) +
                                 k.core.v1.container.withVolumeMounts([
                                   k.core.v1.volumeMount.new('data', '/data'),
                                 ]),
                               ])
      for job in config.jobs
    } +
    if std.extVar('include_images') == 'true' then {
      local c = [
        containerfile.from('debian:' + config.debian_version),
        containerfile.run([
          'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/disable-sandbox',
          'apt-get -qy update',
          'apt-get -qy install curl unzip',
          "curl -sLo /tmp/rclone.zip '%s'" % config.dl_url,
          'unzip /tmp/rclone.zip -d /tmp/rclone',
          'mv /tmp/rclone/rclone-v%s-linux-amd64 /opt/rclone' % config.version,
          'rm -rf /tmp/rclone',
          'install -d -m 755 -o 1000 -g 1000 /.cache',
        ]),
        containerfile.entrypoint(['"/opt/rclone/rclone"']),
      ],
      image: image.fromImageName(config.name, config.image, std.join('\n', c)),
    }
    else {},

}
