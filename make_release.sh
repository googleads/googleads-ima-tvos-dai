#!/bin/bash

# DESCRIPTION
#
# Script to update the files on github for the tvOS IMA SDK samples
#
# USAGE
#
# Make sure to update the number in the VERSION file each time you do a release
#
# Run this script without arguments to add a new entry to the github release
# section with an already built bundle:
#
# ./googlemac/iPhone/InteractiveMediaAds/IMA/tvos/samples/dai/make_release
#
# It will create a zipped up release for ima sdk.
#
# To update the source files and bundled files on GitHub run the following,
# updating the source files is usually done automatically by copybara:
#
# ./googlemac/iPhone/InteractiveMediaAds/IMA/tvos/samples/dai/make_release --update_mode
#
# To build the sample apps through copybara in a temp directory before pushing to GitHub run:
#
# ./googlemac/iPhone/InteractiveMediaAds/IMA/tvos/samples/dai/make_release --test_mode
#
# In the rare case you want to pass additional args to copybara, you can use the following:
#
# ./make_release --copybara_args='--init-history' or ./make_release -a='--init-history'
#
# The above example will append the '--init-history' argument when it runs copybara.
#
# NOTES
#
# If you don't run gcert, this thing will throw all kinds of weird piper
# errors.
#

set -e

GITHUB_OWNER="googleads"
GITHUB_REPOSITORY="googleads-ima-tvos-dai"

# Figure out where we are, get google3 location
GOOGLE3=$(pwd)
if [[ "$(basename "$(pwd)")" != "google3" ]]; then
  GOOGLE3=$(pwd | grep -o ".*/google3/" | grep -o ".*google3")
fi
if [[ -z "${GOOGLE3}" ]]; then
  echo "Error - no google3 in current working directory"
  exit 1
fi

# Parse command line options
TEST_MODE=false
UPDATE_MODE=false
BUILD_BUNDLE=false
for i in "$@" ; do
  case $i in
    --test_mode|-t)
      TEST_MODE=true
      BUILD_BUNDLE=true
      ;;
    --update_mode|-u)
      UPDATE_MODE=true
      BUILD_BUNDLE=true
      ;;
    --copybara_args=*|-a=*)
      # get the argument value - see http://tldp.org/LDP/abs/html/string-manipulation.html (search substring removal)
      COPYBARA_ARGS="${i#*=}"
      echo "copybara args: ${COPYBARA_ARGS}"
      ;;
    *)
      echo "Unknown option $i"
      exit 1
      ;;
  esac
done

VERSION=cat "${GOOGLE3}/googlemac/iPhone/InteractiveMediaAds/IMA/tvos/samples/dai/VERSION"
COPYBARA="/google/data/ro/teams/copybara/copybara"
CONFIG_PATH="${GOOGLE3}/googlemac/iPhone/InteractiveMediaAds/IMA/tvos/samples/dai/copy.bara.sky"
TEMP_DIR="/tmp/copybara_test_tvos_dai_ima"
COMMIT_MSG="Committing latest changes for v${VERSION}"

# Create Copybara change and commit to github (does not commit in test mode)
do_git_push() {
  rm -rf ${TEMP_DIR}

  if [[ $UPDATE_MODE = false ]] ; then
    echo "Creating copybara test change for version ${VERSION}..."
    copybara_cmd="${COPYBARA} ${CONFIG_PATH} postsubmit_piper_to_github -v ${COPYBARA_ARGS} --git-destination-path ${TEMP_DIR} --dry-run --force --squash"
  fi

  if [[ $UPDATE_MODE = true ]] ; then
    echo "Creating Copybara change for version ${VERSION}..."
    copybara_cmd="${COPYBARA} ${CONFIG_PATH} postsubmit_piper_to_github -v ${COPYBARA_ARGS} --git-destination-path ${TEMP_DIR}"
  fi

  # Run this following copybara command to see copybara logs
  echo "Running copybara command: ${copybara_cmd}"

  copybara_output=$"($copybara_cmd 2>&1)"
  echo "googleads copybara complete, output dir: ${TEMP_DIR}"
  if [[ -z "${TEMP_DIR}" ]]; then
    echo "${copybara_output}"
    echo "Error - copybara failed."
    exit 1
  fi
}

do_release_upload() {
  pushd ${TEMP_DIR}
  # Zip up samples and push to github as a release
  # ObjC BasicExample release
  mkdir objc_basic_example
  cp -r ObjectiveC/BasicExample/* objc_basic_example
  zip -r "objc_basic_example_v${VERSION}.zip" objc_basic_example

  # ObjC AdvancedExample release
  mkdir objc_advanced_example
  cp -r ObjectiveC/AdvancedExample/* objc_advanced_example
  zip -r "objc_advanced_example_v${VERSION}.zip" objc_advanced_example

  # ObjC PodservingExample release
  mkdir objc_podserving_example
  cp -r ObjectiveC/PodservingExample/* objc_podserving_example
  zip -r "objc_podserving_example_v${VERSION}.zip" objc_podserving_example

  # ObjC VideoStitcherExample release
  mkdir objc_video_stitcher_example
  cp -r ObjectiveC/VideoStitcherExample/* objc_video_stitcher_example
  zip -r "objc_video_stitcher_example_v${VERSION}.zip" objc_video_stitcher_example

  # Swift BasicExample release
  mkdir swift_basic_example
  cp -r Swift/BasicExample/* swift_basic_example
  zip -r "swift_basic_example_v${VERSION}.zip" swift_basic_example

  # Swift AdvancedExample release
  mkdir swift_advanced_example
  cp -r Swift/AdvancedExample/* swift_advanced_example
  zip -r "swift_advanced_example_v${VERSION}.zip" swift_advanced_example

  # Swift PodservingExample release
  mkdir swift_podserving_example
  cp -r Swift/PodservingExample/* swift_podserving_example
  zip -r "swift_podserving_example_v${VERSION}.zip" swift_podserving_example

  # Swift VideoStitcherExample release
  mkdir swift_video_stitcher_example
  cp -r Swift/VideoStitcherExample/* swift_video_stitcher_example
  zip -r "swift_video_stitcher_example_v${VERSION}.zip" swift_video_stitcher_example

  RELEASE_NOTES="#### Google Ads IMA SDK for DAI tvOS Samples v${VERSION}

|  Project | ObjC Download | Swift Download | Description |
| -------- | ------------- | -------------- | ----------- |
| Basic Integration | [ObjC](https://github.com/googleads/googleads-ima-tvos-dai/releases/download/${VERSION}/objc_basic_example_v${VERSION}.zip) | [Swift](https://github.com/googleads/googleads-ima-tvos-dai/releases/download/${VERSION}/swift_basic_example_v${VERSION}.zip) | Basic IMA SDK DAI integration into a tvOS app. |
| Advanced Integration | [ObjC](https://github.com/googleads/googleads-ima-tvos-dai/releases/download/${VERSION}/objc_advanced_example_v${VERSION}.zip) | [Swift](https://github.com/googleads/googleads-ima-tvos-dai/releases/download/${VERSION}/swift_advanced_example_v${VERSION}.zip) | IMA SDK DAI integration into a tvOS app with live and VOD streams |
| Podserving Integration | [ObjC](https://github.com/googleads/googleads-ima-tvos-dai/releases/download/${VERSION}/objc_podserving_example_v${VERSION}.zip) | [Swift](https://github.com/googleads/googleads-ima-tvos-dai/releases/download/${VERSION}/swift_podserving_example_v${VERSION}.zip) | IMA SDK DAI integration with Pod Serving |
| Cloud Video Stitcher Integration | [ObjC](https://github.com/googleads/googleads-ima-tvos-dai/releases/download/${VERSION}/objc_video_stitcher_example_v${VERSION}.zip) | [Swift](https://github.com/googleads/googleads-ima-tvos-dai/releases/download/${VERSION}/swift_video_stitcher_example_v${VERSION}.zip) | IMA SDK DAI integration with the Cloud Video Stitcher |"

  # Upload release to GitHub
  pushd "${GOOGLE3}"
  echo "Executing the GitHub uploader..."
  #ObjC
  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/objc_basic_example_v${VERSION}.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -n "Google Ads IMA SDK tvOS DAI Samples v${VERSION}" \
      -b "${RELEASE_NOTES}" \
      -c "${COMMIT_MSG}"

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/objc_advanced_example_v${VERSION}.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/objc_podserving_example_v${VERSION}.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/objc_video_stitcher_example_v${VERSION}.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  #Swift
  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_basic_example_v${VERSION}.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_advanced_example_v${VERSION}.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_podserving_example_v${VERSION}.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_video_stitcher_example_v${VERSION}.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a
}

if [[ $BUILD_BUNDLE = true ]] ; then
  do_git_push
fi


if [[ $TEST_MODE = false ]] ; then
  do_release_upload
fi
