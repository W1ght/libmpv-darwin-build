# Fushi unified FFmpeg: libmpv links the SAME FFmpeg frameworks the app ships
# for card mining (FFmpegKitNext build of hajisensai/fushi tool/ffmpeg-unified,
# .github/workflows/ffmpeg-unified-mobile.yml) instead of building its own.
#
# This package exposes one slice of those prebuilt xcframeworks to the mpv
# build as pkg-config modules (-F <dir> -framework libavcodec ...), so the
# linked Mpv binary loads @rpath/libavcodec.framework/libavcodec at runtime.
# The frameworks themselves are NOT repackaged here (mk-out-libs skips them);
# the app bundles them once, from the same build.
{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
  variant ? import ../../utils/default/variant.nix,
  flavor ? import ../../utils/default/flavor.nix,
}:

let
  oses = import ../../utils/constants/oses.nix;
  lock = (import ../../../packages.lock.nix).ffmpeg-unified;
  inherit (lock) version;
  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch variant flavor; };
  # iOS device and simulator slices come from the same xcframeworks.
  platformLock = if os == oses.macos then lock.macos else lock.ios;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "ffmpeg-unified-${if os == oses.macos then "macos" else "ios"}-${version}";
    inherit (platformLock) url sha256;
  };
  slice =
    if os == oses.macos then
      "macos-arm64"
    else if os == oses.ios then
      "ios-arm64"
    else
      "ios-arm64_x86_64-simulator";
in

pkgs.runCommand "ffmpeg-unified-${os}-${arch}-${version}" { } ''
  set -euo pipefail
  mkdir -p $out/Frameworks $out/include $out/lib/pkgconfig
  for xcf in ${src}/lib*.xcframework; do
    lib=$(basename "$xcf" .xcframework)
    fw="$xcf/${slice}/$lib.framework"
    [ -d "$fw" ] || { echo "missing slice ${slice} in $xcf"; exit 1; }
    cp -R "$fw" $out/Frameworks/
    mkdir -p "$out/include/$lib"
    cp -RL "$fw/Headers/." "$out/include/$lib/"

    # pkg-config Version must be the library version (mpv requires e.g.
    # libavcodec >= 60.31.102), read from the headers.
    upper=$(echo "''${lib#lib}" | tr '[:lower:]' '[:upper:]')
    hdr_dir="$out/include/$lib"
    ver_part() {
      grep -hE "#define LIB''${upper}_VERSION_$1 " "$hdr_dir"/version*.h | awk '{print $3}' | head -1
    }
    v="$(ver_part MAJOR).$(ver_part MINOR).$(ver_part MICRO)"
    cat > "$out/lib/pkgconfig/$lib.pc" <<EOF
prefix=$out
includedir=$out/include
Name: $lib
Description: Fushi unified FFmpeg ${version} ($lib)
Version: $v
Libs: -F$out/Frameworks -framework $lib
Cflags: -I$out/include
EOF
    echo "$lib $v"
  done
''
