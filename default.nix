{
  bash,
  buildEnv,
  busybox,
  ceph,
  coreutils,
  curl,
  dockerTools,
  gnused,
  lib,
  lvm2,
  makeWrapper,
  runtimeShell,
  systemdMinimal,
  udev,
  util-linux,
}:
dockerTools.buildImage {
  name = "ghcr.io/ushitora-anqou/ceph";
  tag = "dev";
  created = "now";
  #fromImage = dockerTools.pullImage {
  #  imageName = "ghcr.io/cybozu/ubuntu";
  #  imageDigest = "sha256:df9105ccebcac58335fbdddf04782872e03a263dfd8f0bf97c7e10fe023ac896";
  #  sha256 = "elbEBnyGPYlzupjR7tmtR6A3r9z4GlVcHW0jzC91TKA=";
  #  finalImageName = "ghcr.io/cybozu/ubuntu";
  #  finalImageTag = "22.04";
  #};
  copyToRoot = buildEnv {
    name = "image-root";
    paths = [
      ceph
      coreutils
      curl
      gnused
      lvm2
      systemdMinimal
      util-linux
    ];
  };
  runAsRoot = ''
    #!${runtimeShell}
    ${dockerTools.shadowSetup}

    set -eux

    groupadd -r ceph
    useradd -r -g ceph ceph

    mkdir -p /var/lib/ceph
    chown ceph:ceph /var/lib/ceph
    mkdir -p /run/ceph
    chown ceph:ceph /run/ceph
    ln -s /run /var/run

    #ln -s ${lvm2}/bin/dmsetup /bin
    #ln -s ${lvm2}/bin/lvs /bin

    . ${makeWrapper}/nix-support/setup-hook
    makeWrapper ${bash}/bin/bash /bin/bash \
      --set PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ln -s /bin/bash /bin/sh
  '';
  extraCommands = ''
  '';
  config = {
    Entrypoint = ["bash"];
  };
}
