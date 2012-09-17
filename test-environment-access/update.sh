#!/bin/sh -x

PATH="$PATH:/usr/local/bin"
export PATH

if ! which wget >/dev/null 2>/dev/null; then
  echo "Missing wget, exit."
  exit 1
fi
if [ -z "$HOME" -o ! -d "$HOME" ]; then
  echo "HOME not set, exit."
  exit 2
fi

mkdir -p "$HOME/.ssh" 2>/dev/null
if [ ! -d "$HOME/.ssh" ]; then
  echo "~/.ssh directory does not exist, exit."
  exit 3
fi
mkdir -p "$HOME/test-environment-access/tmp" 2>/dev/null
if [ ! -d "$HOME/test-environment-access/tmp" ]; then
  echo "~/test-environment-access/tmp directory does not exist, exit."
  exit 4
fi

if ! chmod 700 "$HOME/.ssh" >/dev/null 2>/dev/null; then
  echo "Could not set permissions on ~/.ssh to 700, exit."
  exit 5
fi

case "$1" in
  update )
    rm -f -- "$HOME/test-environment-access/tmp/update.sh.$$" &&
    wget -O "$HOME/test-environment-access/tmp/update.sh.$$" "https://svn.opendnssec.org/trunk/testing/test-environment-access/update.sh" &&
    exec sh -x "$HOME/test-environment-access/tmp/update.sh.$$" authorized_keys ||
    {
      echo "Update failed, exit."
      exit 6
    }
    ;;
  authorized_keys )
    if [ "$0" != "$HOME/test-environment-access/update.sh" ]; then
      cp -p -- "$0" "$HOME/test-environment-access/update.sh" ||
      {
        echo "Installing new update.sh failed, exit."
        exit 7
      }
    fi
    rm -f -- "$HOME/test-environment-access/tmp/authorized_keys.$$" &&
    wget -O "$HOME/test-environment-access/tmp/authorized_keys.$$" "https://svn.opendnssec.org/trunk/testing/test-environment-access/authorized_keys" &&
    chmod 640 "$HOME/test-environment-access/tmp/authorized_keys.$$" &&
    mv -- "$HOME/test-environment-access/tmp/authorized_keys.$$" "$HOME/.ssh/authorized_keys" &&
    exec sh -x "$HOME/test-environment-access/update.sh" clean "$$" ||
    {
      echo "Installing new authorized_keys failed, exit."
      exit 8
    }
    ;;
  clean )
    if [ "$2" -ge 1 ] 2>/dev/null; then
      rm -f -- "$HOME/test-environment-access/tmp/update.sh.$2" ||
      {
        echo "Clean up failed, exit."
        exit 9
      }
    fi
    ;;
esac

