sed -n '/-----------------/,$p' $1  > results.txt
grep -i "benchmark" results.txt > res.txt
sed -i "s/benchmarks\/micro\///g"  res.txt
sed -i "s/\./-/" res.txt
while IFS= read -r score; do
for i in 1 2 3 4 5 6
do
export param_$i=`echo $score | awk -v x=$i '{print $x}'`
done
lava-test-case $param_1-$MODE.min --result pass --measurement $param_2
lava-test-case $param_1-$MODE.max --result pass --measurement $param_3
lava-test-case $param_1-$MODE.mean --result pass --measurement $param_4
lava-test-case $param_1-$MODE.stdev --result pass --measurement $param_5
lava-test-case $param_1-$MODE.stdev% --result pass --measurement $param_6
done <  res.txt
