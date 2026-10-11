#!/bin/sh
# Fetch the pinned ShenOSKernel release into DESTDIR.
#
# Source: the community kernel release from Shen-Language/shen-sources,
# downloaded as a checksum-pinned GitHub release asset.  Set
# SHEN_KERNEL_ARCHIVE to the path of an already-downloaded copy of the same
# tarball to build offline; it is accepted only when its SHA-256 matches the
# pinned value.  Nothing is extracted unless a checksum matches, so a changed
# or corrupted archive fails loudly instead of changing the kernel.
#
# All pins are passed in by the Makefile; see KERNEL.md.
set -eu

: "${KERNEL_URL:?}" "${KERNEL_ARCHIVE:?}" "${KERNEL_SHA256:?}" "${DESTDIR:?}"
LOCAL_ARCHIVE=${SHEN_KERNEL_ARCHIVE:-}

verify() {
  # verify FILE SHA256
  [ -f "$1" ] && printf '%s  %s\n' "$2" "$1" | shasum -a 256 -c >/dev/null 2>&1
}

report_mismatch() {
  # report_mismatch SOURCE FILE SHA256
  echo "fetch-kernel: checksum mismatch for $1" >&2
  printf '  expected %s\n  got      ' "$3" >&2
  shasum -a 256 "$2" | cut -d' ' -f1 >&2
}

rm -rf "$DESTDIR"

if [ -n "$LOCAL_ARCHIVE" ]; then
  if ! [ -f "$LOCAL_ARCHIVE" ]; then
    echo "fetch-kernel: SHEN_KERNEL_ARCHIVE does not exist: $LOCAL_ARCHIVE" >&2
    exit 1
  fi
  if ! verify "$LOCAL_ARCHIVE" "$KERNEL_SHA256"; then
    report_mismatch "$LOCAL_ARCHIVE" "$LOCAL_ARCHIVE" "$KERNEL_SHA256"
    exit 1
  fi
  echo "fetch-kernel: using verified local archive $LOCAL_ARCHIVE"
  ARCHIVE=$LOCAL_ARCHIVE
elif verify "$KERNEL_ARCHIVE" "$KERNEL_SHA256"; then
  echo "fetch-kernel: reusing verified $KERNEL_ARCHIVE"
  ARCHIVE=$KERNEL_ARCHIVE
else
  rm -f "$KERNEL_ARCHIVE"
  if ! curl -fsSL "$KERNEL_URL" -o "$KERNEL_ARCHIVE.part"; then
    rm -f "$KERNEL_ARCHIVE.part"
    echo "fetch-kernel: download failed: $KERNEL_URL" >&2
    echo "fetch-kernel: set SHEN_KERNEL_ARCHIVE to a local copy to build offline" >&2
    exit 1
  fi
  mv "$KERNEL_ARCHIVE.part" "$KERNEL_ARCHIVE"
  if ! verify "$KERNEL_ARCHIVE" "$KERNEL_SHA256"; then
    report_mismatch "$KERNEL_URL" "$KERNEL_ARCHIVE" "$KERNEL_SHA256"
    rm -f "$KERNEL_ARCHIVE"
    exit 1
  fi
  echo "fetch-kernel: downloaded $KERNEL_URL"
  ARCHIVE=$KERNEL_ARCHIVE
fi

mkdir -p "$DESTDIR"
tar xzf "$ARCHIVE" -C "$DESTDIR" --strip-components=1

test -f "$DESTDIR/klambda/init.kl"
test -f "$DESTDIR/tests/runme.shen"
touch "$DESTDIR"
