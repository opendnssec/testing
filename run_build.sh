#!/usr/bin/env bash

# Script to aid manual testing using the jenkins test framework and tests
# Taken from https://wiki.opendnssec.org/display/OpenDNSSEC/How+To+Develop+tests+locally#HowToDeveloptestslocally-Runningexistingtestsoptional
# Modified:
# 1. run bash in debug mode is mow an option
# 2. Options tp allow rebuilding of a single component even if the framework thinks it is not necessary
# 3. Option to allow sqlite 3 3.7.X to be built and installed in workspace/root/$INSTALL_TAG/ and for softHSM and OpenDNSSEC to be built against it
# 4. Create log file for each step of the build

unset SOFTHSM_CONF
export INSTALL_TAG=local-test
export BUILD37X=0
export BUILD_MYSQL=0
export FORCE_LDNS=0
export FORCE_SQLITE37X=0
export FORCE_SOFTHSM=0
export FORCE_OPENDNSSEC=0
export PREVENT_CO=0
export FORCE_SVN_RM=0
export URL_SOFTHSM="http://svn.opendnssec.org/trunk/softHSM"
export URL_OPENDNSSEC="http://svn.opendnssec.org/trunk/OpenDNSSEC"
export WORKSPACE_ROOT=~/workspace
export BLAT=0
export PATCH_SOFTHSM=""
export PATCH_OPENDNSSEC=""
export RUN_TESTS=0

usage () {
    echo
    echo "Script to aid manual testing using the jenkins test framework and tests"
    echo "Taken from https://wiki.opendnssec.org/display/OpenDNSSEC/How+To+Develop+tests+locally#HowToDeveloptestslocally-Runningexistingtestsoptional"
    echo	
    echo "Modifications include:"
    echo "1. run bash in debug mode is mow an option"
    echo "2. Options tp allow rebuilding of a single component even if the framework thinks it is not necessary"
    echo "3. Option to allow sqlite 3 3.7.X to be built and installed in workspace/root/$INSTALL_TAG/ and for softHSM and OpenDNSSEC to be built against it"
    echo "4. Create log file for each step of the build"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Supported options:"
    echo "  -u <URL> the URL that you wish to checkout for softHSM (Default: http://svn.opendnssec.org/trunk/softHSM/)"
    echo "  -U <URL> the URL that you wish to checkout for OpenDNSSEC (Default: http://svn.opendnssec.org/trunk/OpenDNSSEC/)"
    echo "  -p </path/file> patch file to apply to the checked out softHSM."
    echo "  -P </path/file> patch file to apply to the checked out OpenDNSSEC."
    echo "  -f force overwriting of the checked out code if the URL changes"
    echo "  -c prevent any checkout"
    echo "  -7 enable building of sqlite 3.7.X"
    echo "  -m build against mysql"
    echo "  -l force rebuild of ldns"
    echo "  -s force rebuild of sqlite 3.7.X (requires -7)"
    echo "  -S force rebuild of softHSM"
    echo "  -o force rebuild of OpenDNSSEC"
    echo "  -r delete install and reinstall"
    echo "  -w <path> specify workspace (default ~/workspace)"
    echo "  -d run in bash debug mode"
    echo "  -t run tests"
    echo "  -h this help"
    exit 0
}

while getopts ":7u:U:p:P:fcmlsSorw:dth" opt; do
    case $opt in
        7  ) BUILD37X=1 ;;
        u  ) URL_SOFTHSM=$OPTARG ;;
        U  ) URL_OPENDNSSEC=$OPTARG ;;
        p  ) PATCH_SOFTHSM=$OPTARG ;;
        P  ) PATCH_OPENDNSSEC=$OPTARG ;;
        f  ) FORCE_SVN_RM=1 ;;
        c  ) PREVENT_CO=1 ;;
        m  ) BUILD_MYSQL=1 ;;
        l  ) FORCE_LDNS=1 ;;
        s  ) FORCE_SQLITE37X=1 ;;
        S  ) FORCE_SOFTHSM=1 ;;
        o  ) FORCE_OPENDNSSEC=1 ;;
        r  ) BLAT=1 ;;
        w  ) WORKSPACE_ROOT=$OPTARG ;;
        d  ) set -x ;;
        t  ) RUN_TESTS=1 ;;
        h  ) usage ;;
        \? ) usage ;;
    esac
done
[ $FORCE_SQLITE37X -eq 1 ] && [ $BUILD37X -eq 0 ] && usage
[ $BUILD_MYSQL -eq 1 ] && [ $BUILD37X -eq 1 ] && usage
[ $FORCE_SQLITE37X -eq 1 ] && [ $BUILD_MYSQL -eq 1 ] && usage
[ ! -f $PATCH_SOFTHSM ] && echo "Error: patch file $PATCH_SOFTHSM does not exist" && usage
[ ! -f $PATCH_OPENDNSSEC ] && echo "Error: patch file $PATCH_OPENDNSSEC does not exist" && usage

# Create workspace and checkout source
[ $BLAT -eq 1 ] && rm -rf $WORKSPACE_ROOT/root/
mkdir -p $WORKSPACE_ROOT
cd $WORKSPACE_ROOT
if [ $PREVENT_CO -eq 0 ] ; then
  if [ $FORCE_SVN_RM -eq 1 ] ; then
    [ -d $WORKSPACE_ROOT/softHSM/ ] && [ $URL_SOFTHSM != `svn info $WORKSPACE_ROOT/softHSM/ | grep URL | awk ' { print $2 } '` ] && rm -rf $WORKSPACE_ROOT/softHSM/
    [ -d $WORKSPACE_ROOT/OpenDNSSEC/ ] && [ $URL_OPENDNSSEC != `svn info $WORKSPACE_ROOT/OpenDNSSEC | grep URL | awk ' { print $2 } '` ] && rm -rf $WORKSPACE_ROOT/OpenDNSSEC/
  else
    if [ -d $WORKSPACE_ROOT/softHSM/ ] ; then
      EXISTING_URL=`svn info $WORKSPACE_ROOT/softHSM/ | grep URL | awk ' { print $2 } '`
      [ $URL_SOFTHSM != $EXISTING_URL ] && echo "Error: Default URL or URL on command line: $URL_SOFTHSM  does not match existing checked out code: $EXISTING_URL" && usage
    fi
    if [ -d $WORKSPACE_ROOT/OpenDNSSEC/ ] ; then
      EXISTING_URL=`svn info $WORKSPACE_ROOT/OpenDNSSEC | grep URL | awk ' { print $2 } '`
      [ $URL_OPENDNSSEC != $EXISTING_URL ] && echo "Error: Default URL or URL on command line: $URL_OPENDNSSEC does not match existing checked out code: $EXISTING_URL" && usage
    fi
  fi
  echo "Checking out softHSM"
  [ -n $URL_SOFTHSM ] && svn co $URL_SOFTHSM softHSM
  echo "Checking out OpenDNSSEC"
  [ -n $URL_OPENDNSSEC ] && svn co $URL_OPENDNSSEC OpenDNSSEC
fi

# Remove lock files that prevent (un-necessary) rebuilding of code
[ $FORCE_LDNS -eq 1 ] && rm -f $WORKSPACE_ROOT/root/$INSTALL_TAG/.ldns.build $WORKSPACE_ROOT/root/$INSTALL_TAG/.ldns.ok
[ $FORCE_SQLITE37X -eq 1 ] && rm -f $WORKSPACE_ROOT/root/$INSTALL_TAG/.sqlite.build $WORKSPACE_ROOT/root/$INSTALL_TAG/.sqlite.ok
[ $FORCE_SOFTHSM -eq 1 ] && rm -f $WORKSPACE_ROOT/root/$INSTALL_TAG/.softhsm.build $WORKSPACE_ROOT/root/$INSTALL_TAG/.softhsm.ok
[ $FORCE_OPENDNSSEC -eq 1 ] && rm -f $WORKSPACE_ROOT/root/$INSTALL_TAG/.opendnssec.build $WORKSPACE_ROOT/root/$INSTALL_TAG/.opendnssec.ok

# Build ldns
echo "Building ldns"
cd $WORKSPACE_ROOT/OpenDNSSEC/testing	
export WORKSPACE=`pwd`
export SVN_REVISION=1
chmod +x build-ldns.sh
./build-ldns.sh 2>&1 | tee ~/build-ldns.log
chmod -x build-ldns.sh

# If requested build sqlite3 3.7.X (At time of writing this was 3.7.16.2)
if [ $BUILD37X -eq 1 ] ; then
  echo "Building Sqlite3" 
  cd $WORKSPACE_ROOT/OpenDNSSEC/testing
  export WORKSPACE=`pwd`
  export SVN_REVISION=1
  chmod +x build-sqlite3.sh
  ./build-sqlite3.sh 2>&1 | tee ~/build-sqlite3.log
  chmod -x build-ldns.sh
fi

# Build softHSM and if necessary build it against sqlite3 3.7.X
echo "Building softHSM"
cd $WORKSPACE_ROOT/softHSM
if [ $PATCH_SOFTHSM ] ; then
  echo "Applying patch $PATCH_SOFTHSM to softHSM"
  cat $PATCH_SOFTHSM | patch -p0 -N
fi
export WORKSPACE=`pwd`
export SVN_REVISION=1
[ -d build ] && cd build && make clean
cd $WORKSPACE_ROOT/softHSM
if [ $BUILD37X -eq 1 ] ; then
  sed 's|--with-sqlite3=.*\&\&|\&\&|' testing/build-softhsm.sh \
    | sed 's|../configure --prefix|../configure --with-sqlite3=\"\$INSTALL_ROOT\" --prefix|' > testing/build-softhsm-7.sh
  chmod +x testing/build-softhsm-7.sh
  ./testing/build-softhsm-7.sh 2>&1 | tee ~/build-softhsm-7.log
  chmod -x testing/build-softhsm-7.sh
else
  chmod +x testing/build-softhsm.sh
  ./testing/build-softhsm.sh 2>&1 | tee ~/build-softhsm.log
  chmod -x testing/build-softhsm.sh
fi

# Build OpenDNSSEC and if necessary build it against sqlite3 3.7.X or mysql
echo "Building OpenDNSSEC"
cd $WORKSPACE_ROOT/OpenDNSSEC
if [ $PATCH_OPENDNSSEC ] ; then
  echo "Applying patch $PATCH_OPENDNSSEC to OpenDNSSEC"
  eval cat $PATCH_OPENDNSSEC | patch -p0 -N
fi
export WORKSPACE=`pwd`
export SVN_REVISION=1
[ -d build ] && cd build && make clean
cd $WORKSPACE_ROOT/OpenDNSSEC
if [ $BUILD37X -eq 1 ] ; then
  sed 's|--with-sqlite3=.*\&\&|\&\&|' testing/build-opendnssec.sh \
    | sed 's|../configure --prefix|../configure --with-sqlite3=\"\$INSTALL_ROOT\" --prefix|' > testing/build-opendnssec-7.sh
  chmod +x testing/build-opendnssec-7.sh
  ./testing/build-opendnssec-7.sh 2>&1 | tee ~/build-opendnssec-7.log
  chmod -x testing/build-opendnssec-7.sh
else
  if [ $BUILD_MYSQL -eq 1 ] ; then
    chmod +x testing/build-opendnssec-mysql.sh
    ./testing/build-opendnssec-mysql.sh 2>&1 | tee ~/build-opendnssec-mysql.log
    chmod -x testing/build-opendnssec-mysql.sh
  else
    chmod +x testing/build-opendnssec.sh
    ./testing/build-opendnssec.sh 2>&1 | tee ~/build-opendnssec.log
    chmod -x testing/build-opendnssec.sh
  fi
fi

if [ $RUN_TESTS -eq 1 ] ; then
  echo "Testing OpenDNSSEC"
  cd $WORKSPACE_ROOT/OpenDNSSEC/testing
  export INSTALL_TAG=local-test
  export WORKSPACE=`pwd`
  export SVN_REVISION=1
  rm -f $WORKSPACE_ROOT/root/$INSTALL_TAG/.opendnssec.ok.test $WORKSPACE_ROOT/root/$INSTALL_TAG/.opendnssec.test 
  chmod +x test-opendnssec.sh
  ./test-opendnssec.sh | grep "#####"
  chmod -x test-opendnssec.sh
fi
