#!/bin/bash
mkdir -p ../Rendu
for D in *; do
    if [[ -f /tmp/StopRendu ]]; then
        break;
    fi
    pushd $D
    if [[ -f .do-not ]]; then
        popd
        continue;
    fi;
    ../../../render.sh
    popd
    EQ=$(grep ${D} ../listing-equipe |cut -d ';' -f 2)
    if [[ "x${EQ}" == "x" ]]; then
        EQ="${D}"
    fi
    mv ${D}/Rendu ../Rendu/${EQ}
    touch ${D}/.do-not
done

