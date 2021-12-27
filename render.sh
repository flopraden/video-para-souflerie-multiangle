#!/usr/bin/bash
# Prérequis: One angle by SeqNum

# Parameters

STACKH=2
STACKW=2
VOLNUMASVID=1

VOLNUM=0
CHAPNUM=0
#set -x
add() { n="$@"; bc <<< "${n// /+}"; }

echo "== Begin =="
# Clean file
rm -f listSeqID listAngle
rm -f AllAngle_*.mkv MultiAngle_*.mp4 *.encode
rm -rf WorkingDir ByVol

mkdir ByVol

# List all seqID of Aerokart and remove "all" non-aerokart videos
ls --color=none *.mp4 |sed -re 's/.*_([0-9]+)_([0-9]+).mp4/\2/g'|grep -E '^[0-9]+$' |sort -u > listSeqID
# List all angles
ls --color=none *.mp4 |sed -re 's/(.*)_([0-9]+)_([0-9]+).mp4/\1/g'|sort -u > listAngle

mapfile -t ANGLES < listAngle
mapfile -t SEQNUMS < listSeqID
# Rename / Copy all filename in working dir
mkdir -p WorkingDir
for F in *.mp4; do
    T=$(echo -n "$F" |sed -re 's/(.*)_([0-9]+)_([0-9]+).mp4/\1_\3.mp4/g')
    cp -l ${F} WorkingDir/${T}
done;

# Vol number as frame ?
if [[ "x${VOLNUMASVID}" == "x1" ]]; then
    ANGLES+=("SUBASVID")
fi;

for SEQNUM in ${SEQNUMS[@]}; do
    VOLNUM=$(( VOLNUM + 1 ))
    echo " ==== Treat ${SEQNUM} / Vol ${VOLNUM} ===="

    # Cleaning files
    rm -f AllAngle_${SEQNUM}.mkv MultiAngle_${SEQNUM}.mp4

    # If it is a bad seqnum, skip the flight
    if [[ -f "${SEQNUM}.bad" ]]; then
        continue;
    fi;

    # Assume all cam are same Heigh/width
    # Find first cam to find Heigh/with
    HEIGHT="xnull"
    WIDTH="xnull"

    for ANGLE in ${ANGLES[@]}; do
        if [[ -f WorkingDir/${ANGLE}_${SEQNUM}.mp4 ]] ; then
            HEIGHT=$(ffprobe -v quiet -print_format json -show_format -show_streams "WorkingDir/${ANGLE}_${SEQNUM}.mp4"  |jq '.streams[0].height')
            WIDTH=$(ffprobe -v quiet -print_format json -show_format -show_streams "WorkingDir/${ANGLE}_${SEQNUM}.mp4"  |jq '.streams[0].width')
            if [[ "x${HEIGHT}" == "xnull" ]]; then
                continue;
            fi;
            if [[ "x${WIDTH}" == "xnull" ]]; then
                continue;
            fi;
            break;
        fi;
    done;

    # No correct file found ?
    if [[ "x${HEIGHT}" == "xnull" ]]; then
        continue;
    fi;
    if [[ "x${WIDTH}" == "xnull" ]]; then
        continue;
    fi;

    # Construct complex filter

    FILEINDEX=0
    INPUTS=""
    MERGE=""
    NAINDEX=1
    VOLNUMSTR=$(printf "%02d" ${VOLNUM})

    COMPLEXFILTER=""


    # Enough grid ?
    if [[ $(( ${STACKH} * ${STACKW} )) < ${#ANGLES[@]} ]]; then
        echo "WARNING: Grid too small : ${STACKH}x${STACKW} / ${#ANGLES[@]}" >&2
    fi;

    LAYERH=""
    for INDH in $(seq 1 ${STACKH}); do
        INDANGLES=$(( (INDH-1) * ${STACKW} ))
        LAYERANGLES=(${ANGLES[@]:${INDANGLES}:${STACKW}})
        SW=$((STACKW - 1))
        LAYER=""
        for INDW in $(seq 0 ${SW}); do
            ANGLE=${LAYERANGLES[${INDW}]}
            if [[ "x${ANGLE}" == "x" ]]; then
                #No more angles? Padding with black vid
                #NA="color=c=black:r=25:d=1:size=${WIDTH}x${HEIGHT}[bgna${NAINDEX}];[bgna${NAINDEX}]drawtext=text=NOT AVAILABLE:fontsize=64:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2[na${NAINDEX}]"
                NA="color=c=black:r=25:d=1:size=${WIDTH}x${HEIGHT}[na${NAINDEX}]"
                COMPLEXFILTER="${COMPLEXFILTER};${NA}"
                LAYER="${LAYER}[na${NAINDEX}]"
                NAINDEX=$((NAINDEX + 1))
                continue;
            fi;
            if [[ "${ANGLE}" == "SUBASVID" ]]; then
                COMPLEXFILTER="${COMPLEXFILTER};color=c=black:r=25:d=1:size=${WIDTH}x${HEIGHT}[bgsub];[bgsub]drawtext=text=Vol ${VOLNUMSTR}:fontsize=64:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2[sub]"
                LAYER="${LAYER}[sub]"
                continue;
            fi;
            if [[ -s WorkingDir/${ANGLE}_${SEQNUM}.mp4 ]]; then
                INPUTS="${INPUTS} -i WorkingDir/${ANGLE}_${SEQNUM}.mp4"
                MERGE="${MERGE} --track-name 0:${ANGLE} WorkingDir/${ANGLE}_${SEQNUM}.mp4"
                LAYER="${LAYER}[${FILEINDEX}:v]"
                FILEINDEX=$((FILEINDEX + 1))
                continue
            fi;
            # Video not avaiblable
            NA="color=c=black:r=25:d=1:size=${WIDTH}x${HEIGHT}[bgna${NAINDEX}];[bgna${NAINDEX}]drawtext=text=NOT AVAILABLE:fontsize=64:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2[na${NAINDEX}]"
            COMPLEXFILTER="${COMPLEXFILTER};${NA}"
            LAYER="${LAYER}[na${NAINDEX}]"
            NAINDEX=$((NAINDEX + 1))
        done;
        #Construct the layer
        if [[ ${STACKW} > 1 ]]; then
            COMPLEXFILTER="${COMPLEXFILTER};${LAYER}hstack=inputs=${STACKW}[L${INDH}]"
        else
            COMPLEXFILTER="${COMPLEXFILTER};${LAYER}copy[L${INDH}]"
        fi
        LAYERH="${LAYERH}[L${INDH}]"
    done
    if [[ ${STACKH} > 1 ]]; then
        COMPLEXFILTER="${COMPLEXFILTER};${LAYERH}vstack=inputs=${STACKH}[vid]"
    else
        COMPLEXFILTER="${COMPLEXFILTER};${LAYERH}copy[vid]"
    fi
    if [[ "x${NAPRESENT}" == "x1" ]]; then
        COMPLEXFILTER="${NA}${COMPLEXFILTER}"
    else
        COMPLEXFILTER=${COMPLEXFILTER#?}
    fi
    echo "   + Mixing"
    ffmpeg ${INPUTS} -filter_complex "${COMPLEXFILTER}" -map "[vid]" MultiAngle_${SEQNUM}.mp4 > MultiAngle_${SEQNUM}.encode 2>&1
    echo "   + Merging"
    mkvmerge -o AllAngle_${SEQNUM}.mkv --track-name 0:MultiAngle MultiAngle_${SEQNUM}.mp4 ${MERGE} > AllAngle_${SEQNUM}.encode 2>&1

    cp -l MultiAngle_${SEQNUM}.mp4 ByVol/Vol${VOLNUMSTR}-MultiAngle.mp4
    cp -l AllAngle_${SEQNUM}.mkv ByVol/Vol${VOLNUMSTR}-AllAngle.mkv
    for ANGLE in ${ANGLES[@]}; do
        if [[ ${ANGLE} == "SUBASVID" ]]; then
            continue
        fi
        cp -l WorkingDir/${ANGLE}_${SEQNUM}.mp4 ByVol/Vol${VOLNUMSTR}-${ANGLE}.mp4
    done;
done

# Generate chapters
mapfile -t ANGLES < listAngle
ANGLES+=(MultiAngle)
pushd ByVol
MERGE=""
for T in ${ANGLES[@]}; do
    echo " ==== Treat ${T} ===="
    CHAPNUM=0
    TIMESTAMP=0
    START=0
    NUM=$(ls -1 Vol*-${T}.mp4|wc -l)
    if [[ ${NUM} > 0 ]]; then
        echo -ne ";FFMETADATA1\ntitle=${T}\nartist=ChallengeIndoor\n\n" > ${T}.chapt.ffmpeg
        echo "   + Chaptering"
        for V in Vol*-${T}.mp4; do
            CHAPNUM=$((CHAPNUM + 1))
            TITRE=$(echo -ne "$V" |cut -d '-' -f 1)
            CHAPNUMSTR=$(printf "%02d" ${CHAPNUM})
            TIMESTAMPHOUR=$(date -d@${TIMESTAMP} -u +%H:%M:%S)
            TIME=$(ffprobe -v quiet -print_format json -show_format -show_streams "${V}"  |jq '.streams[0].duration'|sed -re 's/"//g')
            START=$(bc <<< "(${TIMESTAMP} * 1000) + 100")
            END=$(bc <<< "(${TIMESTAMP} * 1000) + (${TIME} * 1000)")
            echo -ne "[CHAPTER]\nTIMEBASE=1/1000\nSTART=${START}\nEND=${END}\ntitle=${TITRE}\n\n" >> ${T}.chapt.ffmpeg
            echo -ne "file '${V}'\n" >> ${T}.concat
            TIMESTAMP=$(add ${TIMESTAMP} ${TIME})
        done
        echo "   + Concat"
        ffmpeg -f concat -safe 0 -i ${T}.concat -c copy ${T}-nochapt.mp4 >${T}-nochapt.encode 2>&1
        echo "   + Chapter"
        ffmpeg -i ${T}-nochapt.mp4 -i ${T}.chapt.ffmpeg -map_metadata 1 -c copy ${T}.mp4 >${T}.encode 2>&1
        if [[ ${T} == "MultiAngle" ]]; then
            # Add chapter only one time and MultiAngle as first track
            MERGE="--track-name 0:${T} ${T}.mp4 ${MERGE}"
        else
            MERGE="${MERGE} --track-name 0:${T} ${T}-nochapt.mp4"
        fi
    fi
done
echo " ==== Merging ===="
mkvmerge -o AllAngle.mkv ${MERGE} >AllAngle.encode 2>&1
rm -f *-nochapt.mp4

popd

mkdir Rendu
echo " ==== Zipping ===="
cp -l ByVol/*.mp4 ByVol/*.mkv Rendu/

echo "== End =="
