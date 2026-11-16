#!/usr/bin/env bash
# Speak narration/s1.txt ... s6.txt and lay them on the two-minute timeline: build/narration.wav.
# Needs spark-tts (lab-infra, scripts/spark-tts) with a cloned voice, and ffmpeg.
#   VOICE=aharon ./narrate.sh
# It prints the second each scene starts. film.html's SC table and data-in times must match them.
set -euo pipefail
cd "$(dirname "$0")"
voice=${VOICE:-aharon}
lead=0.6 gap=0.45 total=120 tail=2.0
b=build/narration
mkdir -p "$b"

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

sum=0
for i in 1 2 3 4 5 6; do
    spark-tts say --voice "$voice" -o "$b/s$i.mp3" "$(cat narration/s$i.txt)"
    # the mp3's stated length is wrong, so go through wav; then cut the leading silence and keep pauses to 0.42 s
    ffmpeg -y -v error -i "$b/s$i.mp3" -ar 48000 -ac 1 -af \
        "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,silenceremove=stop_periods=-1:stop_duration=0.42:stop_threshold=-48dB:stop_silence=0.42" \
        "$b/p$i.wav"
    sum=$(echo "$sum + $(dur "$b/p$i.wav")" | bc -l)
done

# speed the speech up just enough to fit, never slow it down
room=$(echo "$total - $lead - 5 * $gap - $tail" | bc -l)
tempo=$(echo "t = $sum / $room; if (t < 1) t = 1; t" | bc -l)
printf 'speech %.1f s, room %.1f s, tempo %.3f\n' "$sum" "$room" "$tempo"

inputs=() filter="" mix="" at=$lead
for i in 1 2 3 4 5 6; do
    ffmpeg -y -v error -i "$b/p$i.wav" -af "atempo=$tempo,loudnorm=I=-16:TP=-1.5:LRA=11" -ar 48000 "$b/f$i.wav"
    printf 'scene %d starts at %.2f\n' "$i" "$at"
    inputs+=(-i "$b/f$i.wav")
    filter+="[$((i - 1))]adelay=$(printf '%.0f' "$(echo "$at * 1000" | bc -l)"):all=1[a$i];"
    mix+="[a$i]"
    at=$(echo "$at + $(dur "$b/f$i.wav") + $gap" | bc -l)
done
ffmpeg -y -v error "${inputs[@]}" -filter_complex \
    "$filter${mix}amix=inputs=6:normalize=0,apad=whole_dur=$total,atrim=0:$total[o]" -map "[o]" -ar 48000 build/narration.wav
echo "build/narration.wav: $(dur build/narration.wav) s"
