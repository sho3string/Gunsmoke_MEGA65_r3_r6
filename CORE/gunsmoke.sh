#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAME="${1:-$ROOT/GUNSMOKE.ZIP}"
PREPARED="${2:-$ROOT/gunsmoke_meg65_roms.zip}"
OUT="${3:-$ROOT/arcade/gunsmoke}"
for cmd in unzip perl; do command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }; done
for f in "$MAME" "$PREPARED"; do [[ -f "$f" ]] || { echo "Missing: $f" >&2; exit 1; }; done
mkdir -p "$OUT"

for part in main sound char scr prom; do
  unzip -p "$PREPARED" "gunsmoke_${part}.rom" > "$OUT/gunsmoke_${part}.rom"
done

# Sort the prepared 16-bit map ROM using JTFRAME gfx_sort=hvvvx.
unzip -p "$PREPARED" gunsmoke_map.rom | perl -0777 -e '
  binmode STDIN; binmode STDOUT;
  local $/; my $src = <STDIN>;
  die "Map size must be a multiple of 32\n" if length($src) % 32;
  my $dst = "\0" x length($src);
  for (my $i=0; $i<length($src); ++$i) {
    my $j = ($i & ~0x1e) | (($i & 0x10) >> 3) | (($i & 0x0e) << 1);
    substr($dst,$j,1) = substr($src,$i,1);
  }
  print $dst;
' > "$OUT/gunsmoke_map.rom"

# Rebuild the object ROM from eight original chips and sort gfx_sort=hvvvvxx.
perl - "$MAME" "$OUT/gunsmoke_obj.rom" <<'PERL'
use strict; use warnings;
my ($zip, $output) = @ARGV;
my @pairs = (
  ['06l_gs18.bin','06n_gs22.bin'],
  ['04l_gs17.bin','04n_gs21.bin'],
  ['03l_gs16.bin','03n_gs20.bin'],
  ['01l_gs15.bin','01n_gs19.bin'],
);
sub chip {
  my ($name) = @_;
  open my $fh, '-|', 'unzip', '-p', $zip, $name or die "unzip: $!";
  binmode $fh; local $/; my $data = <$fh>;
  close $fh or die "Cannot read $name\n";
  length($data) == 32768 or die "Invalid chip size: $name\n";
  return $data;
}
my $src = '';
for my $pair (@pairs) {
  my ($even, $odd) = map { chip($_) } @$pair;
  for (my $i=0; $i<32768; ++$i) {
    $src .= substr($even,$i,1) . substr($odd,$i,1);
  }
}
my $dst = "\0" x length($src);
for (my $i=0; $i<length($src); ++$i) {
  my $j = ($i & ~0x7c) | (($i & 0x40) >> 4) | (($i & 0x3c) << 1);
  substr($dst,$j,1) = substr($src,$i,1);
}
open my $out, '>', $output or die "$output: $!";
binmode $out; print {$out} $dst; close $out or die "$output: $!";
PERL

perl -MCompress::Zlib=crc32 -e '
  for my $file (@ARGV) {
    open my $fh, "<", $file or die "$file: $!";
    binmode $fh; local $/; my $data=<$fh>;
    printf "%-24s %7d bytes  CRC32 %08X\n", ($file =~ m{([^/]+)$})[0], length($data), crc32($data);
  }
' "$OUT"/gunsmoke_{main,sound,char,map,scr,obj,prom}.rom
printf '\nROMs written to: %s\n' "$OUT"
