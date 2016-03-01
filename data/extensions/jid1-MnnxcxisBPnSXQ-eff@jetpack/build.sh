#!/bin/bash
# JPM is stupid and includes every file in the root directory. This script 
# copies only the files necessary for the extension into a temp directory 
# and builds the extension from there. 
# usage ./build.sh [-s]
# -s - Include META-INF directory

cd "`dirname $0`"
SRC=src #source directory to build from
PKG=jid1-MnnxcxisBPnSXQ@jetpack-1.0.3.xpi #package name

if [ -d $SRC ]; then
  rm -rf $SRC;
fi;
mkdir $SRC;

cp -r data lib package.json LICENSE locale $SRC;

# If this is a self hosted release include META-INF
if [ $1 == "-s" ]; then
  cp -r META-INF $SRC;
fi;

pushd $SRC;
jpm xpi;
popd;

echo "Build Complete"
