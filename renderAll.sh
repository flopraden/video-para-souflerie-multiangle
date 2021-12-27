#!/bin/bash
mkdir -p ../Rendu
for D in *; do
    pushd $D
    if [[ ! -f .do-not ]]; then
        ../../render.sh
    fi;
    popd
    EQ=$(grep ${D} ../listing-equipe |cut -d ';' -f 2)
    if [[ "x${EQ}" == "x" ]]; then
        EQ="${D}"
    fi
    mv ${D}/Rendu ../Rendu/${EQ}
    touch ${D}/.do-not
done

