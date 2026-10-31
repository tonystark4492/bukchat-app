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
# resize the app window when the keyboard opens (so the chat is not hidden behind it)
python3 - <<'PY'
p="android/app/src/main/AndroidManifest.xml"
s=open(p).read()
key='android:launchMode="singleTask"'
assert key in s
if "windowSoftInputMode" not in s:
    s=s.replace(key,key+'\n            android:windowSoftInputMode="adjustResize"',1)
open(p,"w").write(s)
PY
# keyboard: make the app window shrink when the keyboard opens (so the chat stays visible)
python3 - <<'PY'
p="android/app/src/main/AndroidManifest.xml"
s=open(p).read()
key='android:launchMode="singleTask"'
assert key in s
if "windowSoftInputMode" not in s:
    s=s.replace(key,key+'\n            android:windowSoftInputMode="adjustResize"',1)
open(p,"w").write(s)
PY
# ---- notification extras: soft chime, silent sound and status-bar icon (made here, no files to upload) ----
python3 - <<'PY'
import wave, struct, math, base64, os
RES = "android/app/src/main/res"
os.makedirs(RES + "/raw", exist_ok=True)
RATE = 22050
def tone(buf, f, start, dur, vol):
    for i in range(int(dur * RATE)):
        t = i / RATE
        env = min(1.0, t / 0.015) * math.exp(-5.0 * t / dur)
        j = int(start * RATE) + i
        buf[j] += vol * env * math.sin(2 * math.pi * f * t)
buf = [0.0] * int(0.9 * RATE)
tone(buf, 1046.5, 0.0, 0.5, 0.20)      # soft two-note chime
tone(buf, 1568.0, 0.1, 0.55, 0.16)
peak = max(abs(x) for x in buf) or 1
w = wave.open(RES + "/raw/soft_chime.wav", "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
w.writeframes(b"".join(struct.pack("<h", int(x / peak * 0.32 * 32767)) for x in buf)); w.close()
w = wave.open(RES + "/raw/silent.wav", "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
w.writeframes(b"\x00\x00" * 2205); w.close()
ICONS = {
  "drawable-xhdpi": "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAEq0lEQVR42u2Z34tVVRTHv/vOTMM4iT8mNCx6LmJGoR93IjEwkBAnkMiQeiiCeTBC8iHmbaAHIQkKYSCS8S8QRBAEIYoonMLqYaBCYSQsc6SQEZxpdOZ8evC7cXe7Z+6vcy9jteFw7jl77+9a67vWXmftfaX/WgPCvYjdGQEdMqLvnsMGSr5vA34G3vJzVwHYXb6/bextqcxarVSnnGDAdZIekbTPrs4KcHnEeM3YmywrtMMTa4BfgBvAplZjNvHsw8A8MAusawSjVKegbqAcQpiXdE7SWklPRO+0wEmU/5SkPklTIYQ5oAx0t2xAAvKGpCnguAVJ0nCDYbhSK0csy5iyTNVrSK6LgQA8Dkxzpy0CGXDOnmklhIIxpoz5p2VMW2aodzHXzMvARuA4d1sG7Go2GyXZZ5exYjsObCz0m5CyABwA5izsVCMpL2cBnzLWHHCgmsxCDAC6gF4/l50xFoCtjQpMlN9qjFmg7He9llVSOxswbuYmGg2jJHwmjDHerB6hjpqkW9KHkh6Q9Kmk85J+krRG0rRT6mOSfpUUQghZHewj6SFJP0q6IWlI0rykRyU9Kel5Sb9LekfSku4A0+zi7QUu8vd2CTgGfOfnw/V6IWH/sOd+A3xizLRdTEI2NOyBCqEbJO1w7n/WLKWF11VJg5L+WImtRJEBe+/BpHvB3v3K34EvQgjX2xX/W4ARs3jBjI3V8kLC/pjnXDDGCLClrTW6M0N3lb4ycNshcL/HhhyM4DGXPKecU7Z0tWVfEL+MiUE9fn/SjI7meSFhf9RjT/q5Jyocsdu+U0oERqV2JiGx1v3VrrVJyO2shtXWXRmwOY1VMxY9cjb1Qs78yP7ZhPFSxdraXLTSkeXtwG/AdeAjYH0SswEYBpaAM8BuYC/woq+9fnfGY4ZjIWeM9ca8bhnbi9rxpQZMmr1l378EBhIl3nVRtkx+W/aYscT4AWOl2JMtl9JVDPjAAm65pAY44b7BpMzOEkOq/c48dtBzTyRl+i2Pfb8dHhipYPG2n18Ajvj3ErVbnHfEc9N30QO7CzMgSZ/3AV8nikZDvgdmKhjOa+mYi8D5xENLSWnRW2gmSrwwnOyabldRtpbyee8j1k3g6ULZr1LDv5KsgWrKXV5hIV9OwqXSoEVgX+GbmRxP7HAuv+K0F8NiHHgZ+NyeypLQeA94CfjMRyiZ514x1o62ML+CJ0pAP3A0WYDPeO88mhgQvfEcsAF406GC5/anmI3q03CeDSFkZqkUQrgJLCal+TFJk5Jel9QrKUtK9o/d/6o3Q5K0aIweIIQQljt5zN7j7HSwIhXSQCo9aIyeVk/GmjrT9MblmreIJTO+5Ps/xid9cVt5zRhZs0q08qmOu64Zh0moQUqpSt9MBVZn/6nx1Qd8W/ElpUY9hOf05W2AOmVETKt7mjBgT0fSZgNGnK6jHop9p1eF8hXfhSGfsi3nlA3xm7AADLX1i9uCFyZW8MJSsyd5HfGCF+MWn3NmOdesx4RVw34VLxwy07cS9uPvQ6uO/SpHLv3AD1b4qi/8rr+tRycFemG/C7UNvo4C+1ct+3nnR430FX68XlB65W4RGzL93/6F7S/Mp9XqLkd9OQAAAABJRU5ErkJggg==",
  "drawable-xxhdpi": "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",
  "drawable-xxxhdpi": "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",
}
for d, data in ICONS.items():
    os.makedirs(RES + "/" + d, exist_ok=True)
    open(RES + "/" + d + "/ic_stat_bukchat.png", "wb").write(base64.b64decode(data))
PY
# use our fixed signing key so every build can update the installed app
mkdir -p ~/.android
cp keystore/debug.keystore ~/.android/debug.keystore
