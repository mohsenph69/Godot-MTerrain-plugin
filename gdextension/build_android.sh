#!/bin/bash

$SHELL -c "env -i scons platform=android target=template_release ANDROID_HOME=/home/bardia/Android/Sdk $1"
$SHELL -c "env -i scons platform=android target=template_debug ANDROID_HOME=/home/bardia/Android/Sdk $1"
