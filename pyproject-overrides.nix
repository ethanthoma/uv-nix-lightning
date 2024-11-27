{ pkgs }:
final: prev:
let
  cudaPackageOverrides =
    pkgs.lib.genAttrs
      (pkgs.lib.concatMap
        (pkg: [
          "nvidia-${pkg}-cu11"
          "nvidia-${pkg}-cu12"
        ])
        [
          "cublas"
          "cuda-cupti"
          "cuda-curand"
          "cuda-nvrtc"
          "cuda-runtime"
          "cudnn"
          "cufft"
          "curand"
          "cusolver"
          "cusparse"
          "nccl"
          "nvjitlink"
          "nvtx"
        ]
      )
      (
        name:
        prev.${name}.overrideAttrs (old: {
          autoPatchelfIgnoreMissingDeps = true;
          postFixup = ''
            rm -rf $out/${final.python.sitePackages}/nvidia/{__pycache__,__init__.py}
            ln -sfn $out/${final.python.sitePackages}/nvidia/*/lib/lib*.so* $out/lib
          '';
        })
      );
in
{
  nvidia-cusolver-cu12 = prev.nvidia-cusolver-cu12.overrideAttrs (attrs: {
    propagatedBuildInputs = attrs.propagatedBuildInputs or [ ] ++ [
      final.nvidia-cublas-cu12
    ];
  });

  nvidia-cusparse-cu12 = prev.nvidia-cusparse-cu12.overrideAttrs (attrs: {
    propagatedBuildInputs = attrs.propagatedBuildInputs or [ ] ++ [
      final.nvidia-cublas-cu12
    ];
  });

  torch = prev.torch.overrideAttrs (old: {
    autoPatchelfIgnoreMissingDeps = true;

    propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
      final.numpy
      final.packaging
    ];
  });

  calver = prev.calver.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.wheel ];
  });

  setuptools-scm = prev.setuptools-scm.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.wheel ];
  });

  trove-classifiers = prev.trove-classifiers.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.wheel ];
  });

  pluggy = prev.pluggy.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.wheel ];
  });
}
// cudaPackageOverrides
