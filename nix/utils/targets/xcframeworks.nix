let
  oses = import ../constants/oses.nix;
  archs = import ../constants/archs.nix;
in
[
  {
    os = oses.ios;
    arch = archs.universal;
  }
  {
    os = oses.macos;
    arch = archs.universal;
  }
  # Fushi: Apple Silicon only (the unified FFmpeg frameworks are arm64).
  {
    os = oses.macos;
    arch = archs.arm64;
  }
]
