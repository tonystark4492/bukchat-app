#!/usr/bin/env bash
# Runs on GitHub after "npx cap add android": brands the generated Android project.
set -e
RES=android/app/src/main/res
cp -r resources/res/. "$RES"/
# dark status bar / navigation bar so no white flashes
python3 - <<'PY'
p="android/app/src/main/res/values/styles.xml"
s=open(p).read()
add='''        <item name="android:statusBarColor">#0B0B0B</item>
        <item name="android:navigationBarColor">#0B0B0B</item>
        <item name="android:windowBackground">@color/ic_launcher_background</item>
'''
key='<item name="android:background">@null</item>'
assert key in s
s=s.replace(key,key+"\n"+add,1)
open(p,"w").write(s)
PY
# use our fixed signing key so every build can update the installed app
mkdir -p ~/.android
cp keystore/debug.keystore ~/.android/debug.keystore
