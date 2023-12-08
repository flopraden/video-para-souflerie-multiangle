# video-para-souflerie-multiangle
Generate videos with multi-angle settings from para or souflerie flight

## Big image of every team to spot correct vids
### Rename mpv screen shot
```
for i in mpv-shot00*.jpg; do mv $i VR2Eq${i//mpv-shot00}; done;
```
### Montage of the big picture
montage -pointsize 100 -label %f -frame 5 -background '#336699' -geometry +4+4 VR2Eq*.jpg VR2.jpg

## Merge files
https://stackoverflow.com/questions/7333232/how-to-concatenate-two-mp4-files-using-ffmpeg
```
$ cat mylist.txt
file '/path/to/file1' 
file '/path/to/file2' 
file '/path/to/file3'
$ ffmpeg -f concat -safe 0 -i mylist.txt -c copy output.mp4
```

```
for C in 423 452 540; do 
  for i in Angle Bottom; do 
    F1=$(ls --color=none ${i}CamHD_*_177${C}.mp4) ;
    F2=$(ls --color=none ${i}CamHD_*_177$(( C + 1 )).mp4);
    mv ${F1} ${F1//.mp4}_org.mp4 ;
    mv ${F2} ${F2//.mp4}_org.mp4;
    echo -e "file '${F1//.mp4}_org.mp4'\nfile '${F2//.mp4}_org.mp4'" > ${F2//.mp4}.list ;
    ffmpeg -f concat -safe 0 -i ${F2//.mp4}.list -c copy ${F2}  ;
  done;
done;
```
## Get duration (to detect merge to do)

```
for i in AngleCamHD_*.mp4; do 
  echo -n "$i => "; 
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $i ; 
done
```

## Blank video in case of missing files
ffmpeg -t 10 -s 1920x1080 -f rawvideo -pix_fmt rgb24 -r 25 -i /dev/zero  /tmp/empty.mp4


