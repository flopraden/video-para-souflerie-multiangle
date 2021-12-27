# Non Exist: 132734
SEQ=132610

mkdir -p SepByEq
MAXID=$(cat N2IDEQ|wc -l)

for N in {1..287}; do
    echo "${N} / 287"
    F=""
    while [[ "x${F}" == "x" ]]; do
        # Inc SEQ
        SEQ=$((SEQ + 1))
        F=$(ls AllInOne/AngleCam_*_${SEQ}.mp4 2>/dev/null)
    done;
    GROUPNUM=$(echo "$F" |sed -re 's|.*/AngleCam_([0-9]+)_([0-9]+)\.mp4|\1|g')
    SEQNUM="${SEQ}"

    IDF=$(( ((N - 1) % MAXID) + 1 ))
    IDEQ=$(tail -n +${IDF} N2IDEQ|head -n 1)
    INFOEQ=$(tail -n +${IDEQ} listing-equipe|head -n 1)

    EQ=$(echo -ne "${INFOEQ}" |cut -d ';' -f 1)
    mkdir -p "SepByEq/${EQ}"

    cp -l AllInOne/*_${SEQ}.mp4 "SepByEq/${EQ}/"
done;
