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
    if ! wget --ca-certificate="$HOME/test-environment-access/startssl-ca-bundle.pem" -O "$HOME/test-environment-access/tmp/update.sh.$$" "https://svn.opendnssec.org/trunk/testing/test-environment-access/update.sh"; then
    	if [ -f "$HOME/test-environment-access/ALLOW_INSECURE" ]; then
    		wget --no-check-certificate -O "$HOME/test-environment-access/tmp/update.sh.$$" "https://svn.opendnssec.org/trunk/testing/test-environment-access/update.sh"
    	else
    		false
    	fi
	fi &&
    exec sh -x "$HOME/test-environment-access/tmp/update.sh.$$" authorized_keys ||
    {
      echo "Update failed, exit."
      rm -f -- "$HOME/test-environment-access/tmp/update.sh.$$"
      exit 6
    }
    ;;
  authorized_keys )
    if [ "$0" != "$HOME/test-environment-access/update.sh" ]; then
      mv "$HOME/test-environment-access/update.sh" "$HOME/test-environment-access/update.sh.backup" ||
      {
        echo "Unable to backup current update.sh, exit."
        exec sh -x "$HOME/test-environment-access/update.sh" clean "$$" 10
        exit 10
      }
      cp -p -- "$0" "$HOME/test-environment-access/update.sh" ||
      {
        echo "Installing new update.sh failed, exit."
        mv "$HOME/test-environment-access/update.sh.backup" "$HOME/test-environment-access/update.sh" ||
        {
          echo "Unable to restore backup of current update.sh, exit."
          exit 11
        }
        exec sh -x "$HOME/test-environment-access/update.sh" clean "$$" 7
        exit 7
      }
    fi
    rm -f -- "$HOME/test-environment-access/tmp/authorized_keys.$$" &&
    if ! wget --ca-certificate="$HOME/test-environment-access/startssl-ca-bundle.pem" -O "$HOME/test-environment-access/tmp/authorized_keys.$$" "https://svn.opendnssec.org/trunk/testing/test-environment-access/authorized_keys"; then
    	if [ -f "$HOME/test-environment-access/ALLOW_INSECURE" ]; then
    		wget --no-check-certificate -O "$HOME/test-environment-access/tmp/authorized_keys.$$" "https://svn.opendnssec.org/trunk/testing/test-environment-access/authorized_keys"
    	else
    		false
    	fi
	fi &&
    chmod 640 "$HOME/test-environment-access/tmp/authorized_keys.$$" &&
    mv -- "$HOME/test-environment-access/tmp/authorized_keys.$$" "$HOME/.ssh/authorized_keys" &&
    exec sh -x "$HOME/test-environment-access/update.sh" clean "$$" ||
    {
      echo "Installing new authorized_keys failed, exit."
      rm -f -- "$HOME/test-environment-access/tmp/authorized_keys.$$"
      exec sh -x "$HOME/test-environment-access/update.sh" clean "$$" 8
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
    if [ "$3" -ge 0 ] 2>/dev/null; then
      exit "$3"
    fi
    ;;
esac

